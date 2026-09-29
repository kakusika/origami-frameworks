//! Lifecycle bridge connecting Slint's rendering notifier to offscreen textures.

use anyhow::{Context, Result};
use slint::wgpu_30::wgpu;

/// Bridges Slint's wgpu rendering notifier to an offscreen render texture.
pub struct ViewportBridge {
    width: u32,
    height: u32,
    texture: Option<wgpu::Texture>,
    needs_recreate: bool,
}

impl ViewportBridge {
    /// Creates a new `ViewportBridge` with the specified pixel dimensions.
    pub fn new(width: u32, height: u32) -> Self {
        Self {
            width: width.max(1),
            height: height.max(1),
            texture: None,
            needs_recreate: true,
        }
    }

    /// Returns recommended `WGPUSettings` enabling full vertex storage buffers and standard limits.
    pub fn recommended_wgpu_settings() -> slint::wgpu_30::WGPUSettings {
        let mut settings = slint::wgpu_30::WGPUSettings::default();
        settings.device_required_limits = wgpu::Limits::default();
        settings
    }

    /// Current target width.
    pub fn width(&self) -> u32 {
        self.width
    }

    /// Current target height.
    pub fn height(&self) -> u32 {
        self.height
    }

    /// Returns the current active texture, if created.
    pub fn texture(&self) -> Option<&wgpu::Texture> {
        self.texture.as_ref()
    }

    /// Requests resizing the viewport on the next frame.
    pub fn resize(&mut self, width: u32, height: u32) {
        let w = width.max(1);
        let h = height.max(1);
        if self.width != w || self.height != h {
            self.width = w;
            self.height = h;
            self.needs_recreate = true;
        }
    }

    /// Ensures the render target texture is created and up to date for the given device.
    /// Returns `(texture, was_recreated)`.
    pub fn ensure_texture(&mut self, device: &wgpu::Device) -> Result<(&wgpu::Texture, bool)> {
        let recreated = if self.needs_recreate || self.texture.is_none() {
            let texture = device.create_texture(&wgpu::TextureDescriptor {
                label: Some("origami_viewport_target"),
                size: wgpu::Extent3d {
                    width: self.width,
                    height: self.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::Rgba8Unorm,
                usage: wgpu::TextureUsages::RENDER_ATTACHMENT
                    | wgpu::TextureUsages::TEXTURE_BINDING,
                view_formats: &[],
            });
            self.texture = Some(texture);
            self.needs_recreate = false;
            true
        } else {
            false
        };

        Ok((self.texture.as_ref().unwrap(), recreated))
    }

    /// Converts the current texture into a `slint::Image`.
    pub fn to_slint_image(&self) -> Result<slint::Image> {
        let texture = self
            .texture
            .as_ref()
            .context("texture has not been initialized yet")?;
        slint::Image::try_from(texture.clone())
            .map_err(|e| anyhow::anyhow!("failed to import texture into Slint Image: {e:?}"))
    }
}

/// Returns recommended `WGPUSettings` enabling full vertex storage buffers and standard limits.
pub fn recommended_wgpu_settings() -> slint::wgpu_30::WGPUSettings {
    ViewportBridge::recommended_wgpu_settings()
}
