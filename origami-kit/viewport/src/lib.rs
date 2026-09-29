//! `origami-viewport`: Viewport integration bridge for Slint applications.
//!
//! Provides lifecycle management for offscreen wgpu rendering into Slint UI,
//! along with optional low-level Vulkan / Ash interop utilities.

pub mod bridge;
pub mod vulkan;

pub use bridge::{recommended_wgpu_settings, ViewportBridge};
pub use vulkan::{
    buffer::find_memory_type_index, OffscreenPass, VulkanContext, VulkanDeviceContext,
};
