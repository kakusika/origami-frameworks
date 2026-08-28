//! wgpu-hal経由でVulkanオブジェクトを構築し、Qt側と共有するためのモジュール。
//!
//! 所有権の設計方針(重要):
//!   - VkInstance/VkDevice等の「実体」の所有権は最後までRust側(このモジュール)
//!     が持ち続ける。
//!   - Qt(QVulkanInstance)はハンドルを「借りる」だけで、破棄の責任を負わない
//!     (Qt公式ドキュメント: "QVulkanInstance will not own the handle")。
//!   - したがって、SharedVulkanContext が Drop される前に、必ず
//!     C++側の releaseSharedVulkanInstance() を呼び、Qt側の参照を
//!     切り離してからでないと、Use-after-freeのリスクがある。
//!     呼び出し順序: Rustのdrop準備 -> releaseSharedVulkanInstance() -> 実際のdrop
//!
//! 拡張要件(必須、QVulkanInstance::setVkInstance()のドキュメントに明記):
//!   - VK_KHR_surface
//!   - VK_KHR_wayland_surface (本実装ではWayland環境を前提に選択。
//!     X11環境の場合は VK_KHR_xcb_surface に切り替えること。
//!     4.7/4.11 参照: 実行時判定での自動切り替えは今後の課題)
//!   - VK_EXT_debug_utils (QVulkanInstanceのデバッグ出力を使う場合のみ)
//!
//! これらを有効化せずに setVkInstance() -> create() を呼ぶと、
//! Qt側の初期化が失敗する。

use anyhow::{Context, Result, bail};
use ash::vk;
use std::sync::OnceLock;
use wgpu_hal::Instance as _;

/// 【デバッグ用】VK_LAYER_KHRONOS_validationからのメッセージをstderrに出す。
unsafe extern "system" fn vulkan_debug_callback(
    message_severity: vk::DebugUtilsMessageSeverityFlagsEXT,
    message_types: vk::DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: *const vk::DebugUtilsMessengerCallbackDataEXT<'_>,
    _p_user_data: *mut std::ffi::c_void,
) -> vk::Bool32 {
    let message = unsafe { std::ffi::CStr::from_ptr((*p_callback_data).p_message) };
    eprintln!(
        "[vulkan validation] {message_severity:?} {message_types:?}: {}",
        message.to_string_lossy()
    );
    vk::FALSE
}

/// Rust側が生成・所有するVulkanオブジェクト一式。
/// wgpu-halの `from_raw` 系APIでラップした後は、
/// 通常のwgpu高レベルAPI(wgpu::Instance/Device/Queue)として
/// 描画コードを書くことができる。
pub struct SharedVulkanContext {
    // 生ハンドル: C++側に渡すため、および所有権管理のために保持しておく。
    // entryは値としては読まれないが、ロードしたVulkanローダー(libvulkan.so)を
    // 生存させ続けるために(dropで解放されないよう)保持し続ける必要がある。
    #[allow(dead_code)]
    pub entry: ash::Entry,
    pub raw_instance: ash::Instance,
    pub raw_physical_device: vk::PhysicalDevice,

    /// C++側 (QQuickGraphicsDevice::fromDeviceObjects) に渡すための
    /// 生VkDeviceハンドル。実体(ash::Device)の所有権は wgpu_device
    /// (wgpu-hal経由)が持つため、ここではハンドル値のみを保持する。
    pub raw_device_handle: vk::Device,
    pub queue_family_index: u32,
    pub queue_index: u32,

    // wgpu高レベルAPI: 実際の描画コード(ノード/エッジのインスタンシング等)は
    // こちらを使って書く。wgpu_instanceは値としては読まれないが、
    // wgpu_device/wgpu_queueが依存するリソースを生存させ続けるために保持する。
    #[allow(dead_code)]
    pub wgpu_instance: wgpu::Instance,
    // Kept alongside wgpu_device/wgpu_queue (rather than left as a local
    // dropped after create_device_from_hal) so callers that need to hand
    // the same adapter/device/queue/instance set to a second consumer of
    // this shared context (e.g. bevy's RenderCreation::Manual) don't have
    // to re-derive an adapter, which could resolve to a different one than
    // the physical device actually selected above.
    #[allow(dead_code)]
    pub wgpu_adapter: wgpu::Adapter,
    pub wgpu_device: wgpu::Device,
    pub wgpu_queue: wgpu::Queue,

    // Qt側にこのインスタンスを「渡し終えたか」を記録するフラグ。
    // 渡した後は、drop前に必ずreleaseを行うことを強制するために使う。
    handed_to_qt: bool,
}

/// Ranks physical devices so a real GPU is always preferred over a
/// software rasterizer (e.g. Mesa llvmpipe) when multiple Vulkan devices
/// are present -- vkEnumeratePhysicalDevices' ordering is not guaranteed
/// to put hardware first, and picking the wrong device here silently
/// routes both Qt Quick's own rendering and this renderer's GPU views
/// through the CPU.
fn device_type_rank(device_type: vk::PhysicalDeviceType) -> u8 {
    match device_type {
        vk::PhysicalDeviceType::DISCRETE_GPU => 3,
        vk::PhysicalDeviceType::INTEGRATED_GPU => 2,
        vk::PhysicalDeviceType::VIRTUAL_GPU => 1,
        _ => 0, // CPU (llvmpipe) and OTHER
    }
}

impl SharedVulkanContext {
    /// # Safety
    /// Vulkan APIを直接呼び出すため unsafe。
    /// また、生成したVkInstance/VkDevice等のハンドルをC++側に渡した後は、
    /// このcontextをRust側で先にdropしてはならない
    /// (release_from_qt()を先に呼ぶこと)。
    pub unsafe fn new() -> Result<Self> {
        let entry = unsafe { ash::Entry::load() }.context("failed to load Vulkan entry")?;

        // 【デバッグ用】VK_LAYER_KHRONOS_validationは既定では有効化しない。
        // このレイヤーは全Vulkan呼び出しの状態を影で追跡するため、
        // 常時有効化するとメモリ使用量が数十MB単位で増える
        // (実機測定で約20MBのRSS増を確認済み)。黒い矩形しか表示されない
        // 等の描画不具合を調査するときだけ、環境変数
        // `CETTILA_VULKAN_VALIDATION=1` を設定して有効化する。
        let want_validation = std::env::var_os("CETTILA_VULKAN_VALIDATION").is_some();
        let validation_layer_name = c"VK_LAYER_KHRONOS_validation";
        let validation_layer_available = if want_validation {
            // レイヤーが見つからない環境(VK_LAYER_PATH未設定等)でも
            // vkCreateInstanceが失敗しないよう、まずenumerate_instance_layer_properties
            // で存在確認してから有効化する。
            let available_layers = unsafe { entry.enumerate_instance_layer_properties() }
                .context("vkEnumerateInstanceLayerProperties failed")?;
            let available = available_layers.iter().any(|layer| {
                let name = unsafe { std::ffi::CStr::from_ptr(layer.layer_name.as_ptr()) };
                name == validation_layer_name
            });
            if !available {
                eprintln!(
                    "WARNING: CETTILA_VULKAN_VALIDATION is set but \
                     VK_LAYER_KHRONOS_validation was not found (check VK_LAYER_PATH). \
                     Continuing without validation."
                );
            }
            available
        } else {
            false
        };
        let layer_ptrs: Vec<*const i8> = if validation_layer_available {
            vec![validation_layer_name.as_ptr()]
        } else {
            vec![]
        };

        // --- 1. VkInstance作成: Qt側が要求する拡張を明示的に含める ---
        let mut required_instance_extensions: Vec<&std::ffi::CStr> = vec![
            ash::khr::surface::NAME,
            // NOTE: Linux上ではX11かWaylandかで出し分けが必要。
            // 実行環境判定(環境変数 XDG_SESSION_TYPE 等)を見て切り替えるか、
            // 両方を要求して対応可能な方を使う設計にする。
            // ash::khr::xcb_surface::NAME,
            ash::khr::wayland_surface::NAME,
            // Qt自身がウィンドウ用スワップチェインを作る際、色空間として
            // VK_COLOR_SPACE_PASS_THROUGH_EXTを要求してくることがあり、
            // この拡張が無効だとvkCreateSwapchainKHRが検証エラーになる
            // (実機のVulkanバリデーションレイヤーで確認済み)。
            ash::ext::swapchain_colorspace::NAME,
        ];
        // VK_EXT_debug_utilsはQVulkanInstanceのデバッグ出力機能を使う場合のみ
        // 必要(モジュール冒頭のコメント参照)。バリデーションを使わない
        // 既定の起動では要求しない。
        if validation_layer_available {
            required_instance_extensions.push(ash::ext::debug_utils::NAME);
        }

        let extension_ptrs: Vec<*const i8> = required_instance_extensions
            .iter()
            .map(|ext| ext.as_ptr())
            .collect();

        let app_info = vk::ApplicationInfo::default()
            .application_name(c"origami-vulkan-bridge")
            .api_version(vk::API_VERSION_1_3);

        let mut debug_messenger_info = vk::DebugUtilsMessengerCreateInfoEXT::default()
            .message_severity(
                vk::DebugUtilsMessageSeverityFlagsEXT::WARNING
                    | vk::DebugUtilsMessageSeverityFlagsEXT::ERROR,
            )
            .message_type(
                vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                    | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION
                    | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE,
            )
            .pfn_user_callback(Some(vulkan_debug_callback));

        let mut instance_create_info = vk::InstanceCreateInfo::default()
            .application_info(&app_info)
            .enabled_extension_names(&extension_ptrs)
            .enabled_layer_names(&layer_ptrs);
        if validation_layer_available {
            // p_nextに繋いでおくことで、vkCreateInstance自体の検証メッセージ
            // (レイヤー有効化直後〜vkCreateDevice前)も拾えるようにする。
            instance_create_info = instance_create_info.push_next(&mut debug_messenger_info);
        }

        let raw_instance = unsafe { entry.create_instance(&instance_create_info, None) }
            .context("vkCreateInstance failed")?;

        // インスタンス作成後、恒久的なdebug messengerも別途登録しておく
        // (p_next経由のものはvkCreateInstance/vkDestroyInstanceの範囲でしか
        // 効かないため、以降のvkCreateDevice等のメッセージも拾うために必要)。
        if validation_layer_available {
            let debug_utils_instance = ash::ext::debug_utils::Instance::new(&entry, &raw_instance);
            let _messenger = unsafe {
                debug_utils_instance.create_debug_utils_messenger(&debug_messenger_info, None)
            }
            .context("vkCreateDebugUtilsMessengerEXT failed")?;
            // 【簡略化】このmessengerは明示的にdestroyしていない
            // (デバッグ用の一時的な仕組みのため。VkInstance破棄時に
            // 暗黙的に無効化される)。
        }

        // --- 2. 物理デバイスを選択(ソフトウェアラスタライザより実GPUを優先) ---
        let physical_devices = unsafe { raw_instance.enumerate_physical_devices() }
            .context("vkEnumeratePhysicalDevices failed")?;

        if physical_devices.is_empty() {
            bail!("no Vulkan physical devices found");
        }

        let raw_physical_device = physical_devices
            .iter()
            .copied()
            .max_by_key(|&pd| {
                let props = unsafe { raw_instance.get_physical_device_properties(pd) };
                device_type_rank(props.device_type)
            })
            .context("failed to select a Vulkan physical device")?;

        // --- 3. キューファミリーを探す(グラフィックス対応のもの) ---
        // このqueue_family_indexは、後段のopen_with_callback呼び出しで
        // 必要になる可能性が高い(コールバックのqueue_create_infosを
        // 組み立てる、あるいはwgpu-hal側のデフォルトのキュー選択と
        // 一致しているか確認する用途)ため引き続き計算しておく。
        let queue_family_props = unsafe {
            raw_instance.get_physical_device_queue_family_properties(raw_physical_device)
        };
        let queue_family_index = queue_family_props
            .iter()
            .position(|qfp| qfp.queue_flags.contains(vk::QueueFlags::GRAPHICS))
            .context("no graphics-capable queue family found")?
            as u32;

        // --- 4. VkDeviceの作成はwgpu-hal(open_with_callback)に委譲する ---
        // 当初は自前でash::Deviceを作成しdevice_from_rawで取り込む方式を
        // 検討していたが、device_from_rawの正確なシグネチャが確認できな
        // かったため、公式の低レベルinterop用API `open_with_callback` に
        // 切り替えた。Device作成自体をwgpu-hal側に行わせるため、
        // 自前でのash::Device作成コードはここでは書かない
        // (7節のopen_with_callback呼び出しを参照)。

        // --- 5. wgpu-halでInstanceをラップする ---
        //
        // 【確認済み】wgpu-hal(直近バージョンのソース、
        // wgpu-hal/src/vulkan/instance.rs)で以下のシグネチャを確認した:
        //
        //   pub unsafe fn from_raw(
        //       entry: ash::Entry,
        //       raw_instance: ash::Instance,
        //       instance_api_version: u32,
        //       android_sdk_version: u32,
        //       debug_utils_create_info: Option<super::DebugUtilsCreateInfo>,
        //       extensions: Vec<&'static CStr>,
        //       flags: wgt::InstanceFlags,
        //       memory_budget_thresholds: wgt::MemoryBudgetThresholds,
        //       has_nv_optimus: bool,
        //       drop_callback: Option<crate::DropCallback>,
        //   ) -> Result<Self, crate::InstanceError>
        //
        // 【要注意/バージョン依存】
        //   - debug_utils_create_info は生の vk::DebugUtilsMessengerCreateInfoEXT
        //     ではなく、wgpu-hal独自の `super::DebugUtilsCreateInfo` 型。
        //     デバッグ出力を使わないなら None でよい。
        //   - memory_budget_thresholds という引数が has_nv_optimus の「前」に
        //     ある(古い雛形コメントには無かった引数。バージョンによって
        //     引数の有無・順序が変わる可能性が高いので、実装時に手元の
        //     wgpu-halバージョンのdocs.rsで再確認すること)。
        //   - extensions には `&'static CStr` が必要。本関数内の
        //     required_instance_extensions は ash::khr::*::NAME /
        //     ash::ext::*::NAME を経由しており、これらは 'static な
        //     定数のはずなので、そのまま渡せる想定。
        //   - drop_callback: None にすることで、wgpu-halが
        //     raw_instanceの所有権を引き取る(Rust側のSharedVulkanContext
        //     が最終的な所有者になり、Qt側は借りるだけ、という
        //     モジュール冒頭の所有権設計と一致する)。
        //
        // extensionsは公式ヘルパー wgpu_hal::vulkan::Instance::desired_extensions()
        // が返すセットの「スーパーセット」である必要がある、とAPIドキュメントに
        // 明記されている。今回は自前で列挙したextensionsをそのまま渡しているが、
        // 本来はdesired_extensions()の結果とマージしてから渡す方が安全
        // (今後の検証課題として残す)。
        let hal_instance = unsafe {
            <wgpu_hal::api::Vulkan as wgpu_hal::Api>::Instance::from_raw(
                entry.clone(),
                raw_instance.clone(),
                vk::API_VERSION_1_3,
                0,    // android_sdk_version (Android以外では無視される)
                None, // debug_utils_create_info: デバッグ出力は今回未使用
                required_instance_extensions.clone(),
                wgpu_types::InstanceFlags::empty(),
                wgpu_types::MemoryBudgetThresholds::default(),
                false, // has_nv_optimus
                None,  // drop_callback: wgpu-halに所有権を持たせる
            )
        }
        .context("wgpu_hal::vulkan::Instance::from_raw failed")?;

        // --- 6. enumerate_adaptersで対象physical_deviceに対応するAdapterを取得 ---
        // vulkan::Adapterは`raw_physical_device()`という公開アクセサを
        // 持っている(wgpu-hal 30.0.0 ソースで確認済み)ので、それで
        // 2で選んだraw_physical_deviceと一致するものを選ぶ。
        let exposed_adapters = unsafe { hal_instance.enumerate_adapters(None) };
        let exposed_adapter = exposed_adapters
            .into_iter()
            .find(|a| a.adapter.raw_physical_device() == raw_physical_device)
            .context("no matching wgpu_hal ExposedAdapter found for raw_physical_device")?;

        // --- 7. Deviceを開く(open_with_callbackは使わない) ---
        //
        // 【重大な発見・方針転換】当初はopen_with_callbackのコールバックで
        // queue_create_infosを自前のqueue_family_indexに差し替える方式を
        // 採用していたが、これには効果がないことが実機検証(黒い矩形しか
        // 表示されない=描画コマンドが実際には実行されていない)で判明した。
        // open_with_callbackのソース(wgpu-hal 30.0.0, src/vulkan/adapter.rs)
        // を再確認したところ、vkCreateDevice自体はコールバックで上書きした
        // queue_create_infos(family_infos)を正しく使うが、直後に
        // self.device_from_raw(...)へ渡すqueue_family_indexだけは、
        // コールバック実行前に固定された別のローカル変数
        // `family_info.queue_family_index`(常に0)がそのまま使われており、
        // コールバックによる上書きが一切反映されない
        // (`family_infos`と`family_info`は別物で、後者はcallback後も
        // 更新されない)。
        // つまりwgpu側が実際に保持するVkQueueは常にファミリー0・キュー0番
        // ("vkGetDeviceQueue(device, 0, 0)")になる。今回のGPUのグラフィックス
        // 対応ファミリーが0番でない場合、これは「デバイス作成時に要求して
        // いないファミリーに対してvkGetDeviceQueueを呼ぶ」というVulkan仕様
        //違反(未定義動作)になり、結果としてwgpuの描画コマンドが実際には
        // 存在しない/無効なキューに投げられ、共有VkImageには何も描画され
        // ないまま(=黒)Qt側に渡ってしまう。
        //
        // 対処: open_with_callbackを使わず、`device_from_raw`
        // (`required_device_extensions()`/`physical_device_features()`という
        // 公開ヘルパーと組み合わせて使うことが safety doc で明記されている
        // 正規の低レベルAPI)を直接呼び、family_index/queue_indexを
        // こちらから明示的に指定する。
        let enabled_extensions = exposed_adapter
            .adapter
            .required_device_extensions(wgpu_types::Features::empty());
        let mut enabled_phd_features = exposed_adapter
            .adapter
            .physical_device_features(&enabled_extensions, wgpu_types::Features::empty());

        let queue_priorities = [1.0f32];
        let queue_create_info = vk::DeviceQueueCreateInfo::default()
            .queue_family_index(queue_family_index)
            .queue_priorities(&queue_priorities);
        let extension_ptrs: Vec<*const i8> =
            enabled_extensions.iter().map(|ext| ext.as_ptr()).collect();
        let pre_info = vk::DeviceCreateInfo::default()
            .queue_create_infos(std::slice::from_ref(&queue_create_info))
            .enabled_extension_names(&extension_ptrs);
        let device_create_info = enabled_phd_features.add_to_device_create(pre_info);

        let raw_device =
            unsafe { raw_instance.create_device(raw_physical_device, &device_create_info, None) }
                .context("vkCreateDevice failed")?;

        let open_device = unsafe {
            exposed_adapter.adapter.device_from_raw(
                raw_device,
                // drop_callback: None -> raw_deviceの破棄責任はwgpu-halに持たせる
                // (SharedVulkanContext冒頭の所有権設計と一致)
                None,
                &enabled_extensions,
                wgpu_types::Features::empty(),
                &wgpu_types::Limits::default(),
                &wgpu_types::MemoryHints::default(),
                queue_family_index,
                0,
            )
        }
        .context("wgpu_hal::vulkan::Adapter::device_from_raw failed")?;

        // open_deviceはこの後create_device_from_halに消費されるため、
        // Qtに渡す生ハンドルは先にここで取り出しておく。
        let raw_device_handle: vk::Device = open_device.device.raw_device().handle();

        // --- 8. wgpu高レベルAPI(Instance/Adapter/Device/Queue)へ昇格する ---
        let wgpu_instance =
            unsafe { wgpu::Instance::from_hal::<wgpu_hal::api::Vulkan>(hal_instance) };
        let wgpu_adapter = unsafe {
            wgpu_instance.create_adapter_from_hal::<wgpu_hal::api::Vulkan>(exposed_adapter)
        };
        let (wgpu_device, wgpu_queue) = unsafe {
            wgpu_adapter.create_device_from_hal::<wgpu_hal::api::Vulkan>(
                open_device,
                &wgpu::DeviceDescriptor::default(),
            )
        }
        .context("wgpu::Adapter::create_device_from_hal failed")?;

        Ok(Self {
            entry,
            raw_instance,
            raw_physical_device,
            raw_device_handle,
            queue_family_index,
            queue_index: 0,
            wgpu_instance,
            wgpu_adapter,
            wgpu_device,
            wgpu_queue,
            handed_to_qt: false,
        })
    }

    /// C++側に生ハンドルを渡す直前に呼ぶ。呼んだことを記録し、
    /// 誤ってこのcontextを先にdropしないようにする。
    pub fn mark_handed_to_qt(&mut self) {
        self.handed_to_qt = true;
    }
}

impl Drop for SharedVulkanContext {
    fn drop(&mut self) {
        if self.handed_to_qt {
            // Qt側にハンドルを渡した後は、releaseSharedVulkanInstance()を
            // 呼んでからdropする契約になっている。ここに来た場合は契約違反。
            eprintln!(
                "WARNING: SharedVulkanContext dropped while still shared with Qt. \
                 Call release from C++ (releaseSharedVulkanInstance) before this drop."
            );
        }
        // 実際のVulkanオブジェクト破棄はash/wgpu-halのDrop実装に任せる
        // (フィールド宣言順の逆順でdropされる)
    }
}

/// プロセス全体で1つだけ生成される`SharedVulkanContext`の置き場所。
///
/// GraphView/GraphMapView/GraphView3D(それぞれ独自のVulkanレンダラーを
/// 持つ)は、以前はmain()がアプリ起動直後・ユーザーがそのタブを一度も
/// 開かなくても無条件で全レンダラーを構築していた。シェーダー/パイプライン
/// コンパイルはGPUドライバ内部で一時的に大きなメモリを使うため、これが
/// 起動直後の高いRSSの主因になっていた(heaptrackで計測した際、Rust/C++側の
/// mallocヒープはピークでも約200MBほぼ一定で、後から大量解放される様子が
/// なかった -- つまり原因はmallocの外側=ドライバ側だった)。
///
/// 各ビューは自分のQML Itemが最初にマテリアライズされたタイミングで
/// 初めてレンダラーを構築する(各クレートの`ensure_installed()`参照)ように
/// なったため、このcontextだけは引き続きQGuiApplication構築前にmain()が
/// 生成し、生成後すぐここへ格納して、以降は`shared()`経由で必要なときに
/// 参照する。
static SHARED: OnceLock<SharedVulkanContext> = OnceLock::new();

/// `main()`から一度だけ呼ぶ。以降は`shared()`で参照する。
///
/// 保存済みワークスペースの初期アクティブタブがgraphview/graphmap/
/// graphview3dだった場合、対応する`ensure_installed()`はQMLロード中
/// (`main()`がQGuiApplication構築やウィンドウ生成を終えるより前)に
/// 同期的に呼ばれ得るため、`SharedVulkanContext::new()`の直後、
/// QGuiApplication構築より前に呼ぶこと。
///
/// `render_bridge::GRAPH_RENDERER`等の他のOnceLockと同じく、ここに
/// 格納した値は明示的にdropされない(static値はmain()が返ってもデストラクタが
/// 走らない)。プロセス終了時にOSがVkInstance/VkDevice等をまとめて回収する
/// ため実害はなく、`release_shared_vulkan_instance()`/`destroyEngine()`
/// (main()終了時に明示的に呼ぶ)によるQt側の参照切り離し自体はこれまで通り
/// 先に完了する。
pub fn install_shared(ctx: SharedVulkanContext) {
    if SHARED.set(ctx).is_err() {
        panic!("vulkan_bridge::install_shared called more than once");
    }
}

/// `install_shared()`が格納したプロセス全体の`SharedVulkanContext`。
/// `install_shared()`より前に呼ぶとpanicする。
pub fn shared() -> &'static SharedVulkanContext {
    SHARED
        .get()
        .expect("vulkan_bridge::shared() called before install_shared()")
}
