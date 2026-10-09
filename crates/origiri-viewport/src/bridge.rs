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
                label: Some("origiri_viewport_target"),
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
                    | wgpu::TextureUsages::TEXTURE_BINDING
                    | wgpu::TextureUsages::COPY_SRC,
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
    /// Note: This only works with hardware-accelerated Slint backends (wgpu renderer).
    pub fn to_slint_image(&self) -> Result<slint::Image> {
        let texture = self
            .texture
            .as_ref()
            .context("texture has not been initialized yet")?;
        slint::Image::try_from(texture.clone())
            .map_err(|e| anyhow::anyhow!("failed to import texture into Slint Image: {e:?}"))
    }

    /// Reads back the rendered texture into a CPU-backed Slint `Image`.
    /// This is compatible with Slint's `software_renderer` and headless/Wayland SHM buffers.
    pub fn read_to_image(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
    ) -> Result<slint::Image> {
        let texture = self
            .texture
            .as_ref()
            .context("texture has not been initialized yet")?;

        let bytes_per_pixel = 4u32;
        let unpadded_bytes_per_row = self.width * bytes_per_pixel;
        let align = wgpu::COPY_BYTES_PER_ROW_ALIGNMENT;
        let padded_bytes_per_row = ((unpadded_bytes_per_row + align - 1) / align) * align;
        let buffer_size = (padded_bytes_per_row * self.height) as u64;

        let staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("origiri_viewport_staging_buffer"),
            size: buffer_size,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("origiri_viewport_readback_encoder"),
        });

        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &staging_buffer,
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(padded_bytes_per_row),
                    rows_per_image: Some(self.height),
                },
            },
            wgpu::Extent3d {
                width: self.width,
                height: self.height,
                depth_or_array_layers: 1,
            },
        );

        queue.submit(std::iter::once(encoder.finish()));

        let buffer_slice = staging_buffer.slice(..);
        let (tx, rx) = std::sync::mpsc::channel();
        buffer_slice.map_async(wgpu::MapMode::Read, move |res| {
            let _ = tx.send(res);
        });

        device
            .poll(wgpu::PollType::Wait {
                submission_index: None,
                timeout: None,
            })
            .map_err(|e| anyhow::anyhow!("device poll failed: {e:?}"))?;

        rx.recv()
            .map_err(|e| anyhow::anyhow!("failed to wait for staging buffer mapping: {e}"))?
            .map_err(|e| anyhow::anyhow!("staging buffer mapping error: {e}"))?;

        let data = buffer_slice
            .get_mapped_range()
            .map_err(|e| anyhow::anyhow!("failed to get mapped range: {e:?}"))?;
        let mut pixels = Vec::with_capacity((self.width * self.height * bytes_per_pixel) as usize);

        for row in 0..self.height {
            let start = (row * padded_bytes_per_row) as usize;
            let end = start + unpadded_bytes_per_row as usize;
            pixels.extend_from_slice(&data[start..end]);
        }

        drop(data);
        staging_buffer.unmap();

        let mut pixel_buffer =
            slint::SharedPixelBuffer::<slint::Rgba8Pixel>::new(self.width, self.height);
        pixel_buffer.make_mut_bytes().copy_from_slice(&pixels);

        Ok(slint::Image::from_rgba8_premultiplied(pixel_buffer))
    }
}

/// Returns recommended `WGPUSettings` enabling full vertex storage buffers and standard limits.
pub fn recommended_wgpu_settings() -> slint::wgpu_30::WGPUSettings {
    ViewportBridge::recommended_wgpu_settings()
}
