//! Vulkan context extraction from wgpu objects.

use anyhow::{Context, Result};
use ash::vk;

/// Shared Vulkan handles extracted from Slint's / wgpu's device and queue.
#[derive(Clone)]
pub struct VulkanContext {
    pub ash_device: ash::Device,
    pub memory_properties: vk::PhysicalDeviceMemoryProperties,
    pub queue: vk::Queue,
    pub queue_family_index: u32,
}

impl VulkanContext {
    /// Extracts the Vulkan objects from a wgpu device and queue.
    ///
    /// # Safety
    /// The `device` and `queue` must be backed by Vulkan.
    pub unsafe fn from_wgpu(device: &wgpu::Device, queue: &wgpu::Queue) -> Result<Self> {
        let hal_device = unsafe { device.as_hal::<wgpu_hal::api::Vulkan>() }
            .context("wgpu::Device::as_hal::<Vulkan> returned None")?;
        let ash_device = hal_device.raw_device().clone();
        let raw_instance = hal_device.shared_instance().raw_instance();
        let physical_device = hal_device.raw_physical_device();
        let memory_properties =
            unsafe { raw_instance.get_physical_device_memory_properties(physical_device) };
        let hal_queue = unsafe { queue.as_hal::<wgpu_hal::api::Vulkan>() }
            .context("wgpu::Queue::as_hal::<Vulkan> returned None")?;
        let queue = hal_queue.as_raw();
        // wgpu typically uses queue family index 0 for graphics/compute universal queue
        let queue_family_index = 0;

        Ok(Self {
            ash_device,
            memory_properties,
            queue,
            queue_family_index,
        })
    }
}
