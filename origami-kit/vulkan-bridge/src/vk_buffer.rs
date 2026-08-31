//! Low-level Vulkan helpers for QSGRenderNode-style renderers that draw
//! directly into a Qt-owned, in-flight `VkCommandBuffer` (so they build
//! their own `VkPipeline`/buffers via `ash` rather than wgpu's high-level
//! `create_render_pipeline`). Each renderer owns its own
//! `ash::Device`/`VkPhysicalDeviceMemoryProperties` pair (no shared
//! renderer state), but all of them need the same SPIR-V compilation,
//! sample-count mapping, and host-visible/host-coherent vertex-buffer
//! bookkeeping, so it lives here once instead of being copy-pasted per
//! renderer.

use anyhow::{Context, Result, bail};
use ash::vk;

pub struct GpuBuffer {
    pub buffer: vk::Buffer,
    pub memory: vk::DeviceMemory,
}

/// Compiles a WGSL source string to SPIR-V (as a `u32` word stream) for the
/// given entry point.
pub fn compile_spirv(src: &str, stage: naga::ShaderStage, entry_point: &str) -> Result<Vec<u32>> {
    let module = naga::front::wgsl::parse_str(src).context("WGSL parse error")?;
    let info = naga::valid::Validator::new(
        naga::valid::ValidationFlags::all(),
        // IMMEDIATES is required to use var<immediate> (push constants).
        naga::valid::Capabilities::IMMEDIATES,
    )
    .validate(&module)
    .context("WGSL validation error")?;

    let options = naga::back::spv::Options::default();
    let pipeline_options = naga::back::spv::PipelineOptions {
        shader_stage: stage,
        entry_point: entry_point.to_string(),
    };
    naga::back::spv::write_vec(&module, &info, &options, Some(&pipeline_options))
        .context("WGSL->SPIR-V compilation failed")
}

pub fn sample_count_flags(sample_count: u32) -> vk::SampleCountFlags {
    match sample_count {
        1 => vk::SampleCountFlags::TYPE_1,
        2 => vk::SampleCountFlags::TYPE_2,
        4 => vk::SampleCountFlags::TYPE_4,
        8 => vk::SampleCountFlags::TYPE_8,
        16 => vk::SampleCountFlags::TYPE_16,
        _ => vk::SampleCountFlags::TYPE_1,
    }
}

/// Finds the index, within `memory_properties`, of a memory type that
/// satisfies `type_bits` (the bitmask returned by
/// `vkGetBufferMemoryRequirements`) and includes `required_flags`.
pub fn find_memory_type_index(
    memory_properties: &vk::PhysicalDeviceMemoryProperties,
    type_bits: u32,
    required_flags: vk::MemoryPropertyFlags,
) -> Result<u32> {
    for i in 0..memory_properties.memory_type_count {
        let type_matches = (type_bits & (1 << i)) != 0;
        let flags_match = memory_properties.memory_types[i as usize]
            .property_flags
            .contains(required_flags);
        if type_matches && flags_match {
            return Ok(i);
        }
    }
    bail!(
        "no suitable Vulkan memory type found (type_bits={type_bits:#x}, required={required_flags:?})"
    )
}

/// Creates a new host-visible/host-coherent `VkBuffer` (VERTEX_BUFFER
/// usage) with the same contents as `data`. Returns `None` if `data` is
/// empty, since Vulkan doesn't allow zero-size buffer creation.
///
/// # Safety
/// `ash_device` must be a valid `VkDevice`, and `memory_properties` must be
/// the memory properties of the physical device `ash_device` was created
/// from.
pub unsafe fn create_instance_buffer<T>(
    ash_device: &ash::Device,
    memory_properties: &vk::PhysicalDeviceMemoryProperties,
    data: &[T],
) -> Result<Option<GpuBuffer>> {
    if data.is_empty() {
        return Ok(None);
    }
    let size = (data.len() * std::mem::size_of::<T>()) as vk::DeviceSize;

    let buffer_info = vk::BufferCreateInfo::default()
        .size(size)
        .usage(vk::BufferUsageFlags::VERTEX_BUFFER)
        .sharing_mode(vk::SharingMode::EXCLUSIVE);
    let buffer =
        unsafe { ash_device.create_buffer(&buffer_info, None) }.context("vkCreateBuffer failed")?;

    let requirements = unsafe { ash_device.get_buffer_memory_requirements(buffer) };
    let memory_type_index = find_memory_type_index(
        memory_properties,
        requirements.memory_type_bits,
        vk::MemoryPropertyFlags::HOST_VISIBLE | vk::MemoryPropertyFlags::HOST_COHERENT,
    )?;

    let alloc_info = vk::MemoryAllocateInfo::default()
        .allocation_size(requirements.size)
        .memory_type_index(memory_type_index);
    let memory = unsafe { ash_device.allocate_memory(&alloc_info, None) }
        .context("vkAllocateMemory failed")?;

    unsafe { ash_device.bind_buffer_memory(buffer, memory, 0) }
        .context("vkBindBufferMemory failed")?;

    let gpu_buffer = GpuBuffer { buffer, memory };
    unsafe { write_into_buffer(ash_device, &gpu_buffer, data) };

    Ok(Some(gpu_buffer))
}

/// Overwrites the contents of an existing `GpuBuffer` (host-visible/
/// host-coherent memory) with `data`. Never reallocates the buffer.
///
/// # Safety
/// `buf` must be bound to host-visible/host-coherent memory on
/// `ash_device`, sized at least `data`'s byte length. The GPU must not
/// still be referencing this buffer (the caller must have already waited
/// for the previous frame's draw commands to finish, as documented on
/// each renderer's `update_instances`).
pub unsafe fn write_into_buffer<T>(ash_device: &ash::Device, buf: &GpuBuffer, data: &[T]) {
    if data.is_empty() {
        return;
    }
    let size = (data.len() * std::mem::size_of::<T>()) as vk::DeviceSize;
    unsafe {
        let ptr = ash_device
            .map_memory(buf.memory, 0, size, vk::MemoryMapFlags::empty())
            .expect("vkMapMemory failed");
        std::ptr::copy_nonoverlapping(data.as_ptr() as *const u8, ptr as *mut u8, size as usize);
        // HOST_COHERENT, so no explicit vkFlushMappedMemoryRanges is needed.
        ash_device.unmap_memory(buf.memory);
    }
}

/// # Safety
/// `ash_device` must be a valid `VkDevice`, and `buf`'s buffer/memory must
/// not currently be referenced by any command buffer (the caller must
/// guarantee no draw is in flight).
pub unsafe fn destroy_gpu_buffer(ash_device: &ash::Device, buf: GpuBuffer) {
    unsafe {
        ash_device.destroy_buffer(buf.buffer, None);
        ash_device.free_memory(buf.memory, None);
    }
}

/// Owns an optional `GpuBuffer` sized to the largest `update()` call seen so
/// far, reused in place (via `write_into_buffer`) whenever a later call's
/// data still fits, and only destroyed + recreated when it needs to grow.
/// Consolidates the "reuse if big enough, else destroy+recreate" pattern
/// this crate's renderers each used to hand-roll separately per instance
/// buffer (`graph_render`'s circle/line/hull/ring, `graph_render_3d`'s
/// sphere/line, `painter_render`'s stamp instances).
///
/// A buffer bigger than what the most recent `update()` actually wrote is
/// harmless: every renderer's own draw call already requests exactly its
/// own tracked instance *count*, independent of the buffer's total
/// capacity, so this type doesn't need to track (or care about) that count
/// itself -- callers keep doing so themselves, right alongside each
/// `update()` call.
pub struct GrowableInstanceBuffer<T> {
    buffer: Option<GpuBuffer>,
    capacity_bytes: usize,
    _marker: std::marker::PhantomData<T>,
}

impl<T> Default for GrowableInstanceBuffer<T> {
    fn default() -> Self {
        Self {
            buffer: None,
            capacity_bytes: 0,
            _marker: std::marker::PhantomData,
        }
    }
}

impl<T> GrowableInstanceBuffer<T> {
    pub fn buffer(&self) -> Option<&GpuBuffer> {
        self.buffer.as_ref()
    }

    /// Reuses or (re)creates this buffer's backing memory so it holds
    /// `data`. `wait_idle` is called at most once, and only immediately
    /// before this touches memory the GPU might still be reading from a
    /// previous frame's draw -- i.e. before overwriting the existing
    /// buffer in place, or before freeing it to replace it with a bigger
    /// one. Never called on the very first `update()` (no prior buffer
    /// exists yet, so there's nothing the GPU could be reading).
    ///
    /// # Safety
    /// `ash_device` must be a valid `VkDevice`, and `memory_properties`
    /// must be the memory properties of the physical device `ash_device`
    /// was created from -- same as `create_instance_buffer`. `wait_idle`
    /// must actually block until the GPU has finished with this buffer's
    /// prior contents before returning (see `write_into_buffer`'s own
    /// Safety doc for why this is required before overwriting live
    /// GPU-visible memory).
    pub unsafe fn update(
        &mut self,
        ash_device: &ash::Device,
        memory_properties: &vk::PhysicalDeviceMemoryProperties,
        data: &[T],
        wait_idle: impl FnOnce(),
    ) -> Result<()> {
        let needed_bytes = std::mem::size_of_val(data);
        if self.buffer.is_some() && needed_bytes <= self.capacity_bytes {
            wait_idle();
            unsafe { write_into_buffer(ash_device, self.buffer.as_ref().unwrap(), data) };
        } else {
            if let Some(old) = self.buffer.take() {
                wait_idle();
                unsafe { destroy_gpu_buffer(ash_device, old) };
            }
            self.buffer = unsafe { create_instance_buffer(ash_device, memory_properties, data) }?;
            self.capacity_bytes = needed_bytes;
        }
        Ok(())
    }

    /// # Safety
    /// Same as `destroy_gpu_buffer`: `ash_device` must be valid, and the
    /// buffer (if any) must not currently be referenced by any command
    /// buffer.
    pub unsafe fn destroy(&mut self, ash_device: &ash::Device) {
        if let Some(buf) = self.buffer.take() {
            unsafe { destroy_gpu_buffer(ash_device, buf) };
        }
    }
}
