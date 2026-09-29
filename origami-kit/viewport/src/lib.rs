//! `origami-viewport`: Viewport integration bridge for Slint applications.
//!
//! Provides lifecycle management for offscreen wgpu rendering into Slint UI,
//! along with optional low-level Vulkan / Ash interop utilities.

pub mod bridge;
pub mod vulkan;

pub use bridge::ViewportBridge;
pub use vulkan::{OffscreenPass, VulkanContext};
