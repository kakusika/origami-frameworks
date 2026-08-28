# origami-vulkan-bridge

Vulkanオブジェクト(`VkInstance`/`VkPhysicalDevice`/`VkDevice`)をRust側
(本クレート)が所有し、Qt Quickのシーングラフと共有するための低レベルな
統合レイヤー。特定のビュー/アプリのデータ構造やアルゴリズムは扱わない。

cettilaのノートグラフビュー(`GraphView.qml`)をwgpu/Vulkanで描画するための
土台として作られ、`crates/renderer`(cettila-renderer)から切り出された。
Qt/cxx-qtに依存するグルーコードはこのクレートには含めず、利用側アプリに
置く。

## 提供するもの

- `vulkan_bridge::SharedVulkanContext`
  - `ash`でVkInstance/VkPhysicalDevice/VkDeviceを作成し、
    `wgpu-hal`経由で`wgpu::Instance`/`Device`/`Queue`に昇格させる。
  - 生成した実体の所有権は最後までRust側が持ち続ける。Qt
    (`QVulkanInstance`)はハンドルを借りるだけで破棄の責任を負わない。
  - `mark_handed_to_qt()`でQt側に渡したことを記録し、`Drop`時に
    正しい解放順序(Qt側の`releaseSharedVulkanInstance()`が先)が
    守られているかを検査する。
- `vk_buffer`
  - WGSLシェーダーを`naga`でSPIR-Vにコンパイルする`compile_spirv`。
  - host-visible/host-coherentな頂点バッファ作成・書き込み・破棄と、
    「足りていれば使い回し、足りなければ作り直す」を扱う
    `GrowableInstanceBuffer`。
  - QSGRenderNode方式(記録中のVkCommandBufferに直接描画コマンドを
    追記する)のレンダラーが、`ash`で直接`VkPipeline`を組み立てる際に
    必要になる低レベルヘルパー群。

## なぜこの構成か

Qt自身が管理するVkImage/レンダーパスにそのまま描画コマンドを注入する
方式にすることで、「wgpuが自前のVkImageに描いてからQt側にハンドルを
渡す」方式で生じるリサイズ時のフレーム落ちを避けている。詳細な設計判断
の経緯はcettilaの`features/link-graph/2d/HISTORY.md`を参照。

## 使う側の責務

このクレートはVulkan/wgpuの範囲のみを扱う。以下はすべて利用側アプリの
責務:

- Qt Quickの`QQuickWindow`/`QSGRenderNode`のセットアップ(cxx-qt経由)
- `SharedVulkanContext`の生ハンドルをQt側API
  (`QQuickGraphicsDevice::fromDeviceObjects`等)へ橋渡しするC++コード
- `handed_to_qt`のライフサイクル契約を守った解放順序の実行
  (Qt側解放 → `SharedVulkanContext`のdrop)
- 実際の頂点/インスタンスジオメトリ、シェーダー、パイプラインレイアウト
  の設計(cettilaの`graph_render`/`hex_render`/`painter_render`のような
  ビュー固有のレンダラーは、このクレートの外に置く)
