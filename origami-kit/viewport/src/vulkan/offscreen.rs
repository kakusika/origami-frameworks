//! Offscreen rendering pipeline targeting a wgpu::Texture's underlying VkImage.

use crate::vulkan::VulkanContext;
use anyhow::{Context, Result};
use ash::vk;

/// Manages an offscreen Vulkan render pass drawing directly into a `wgpu::Texture`.
pub struct OffscreenPass {
    context: VulkanContext,
    command_pool: vk::CommandPool,
    render_pass: vk::RenderPass,
    clear_color: [f32; 4],
}

impl OffscreenPass {
    /// Creates a new offscreen render pass using the given Vulkan context.
    ///
    /// # Safety
    /// The Vulkan context must be valid.
    pub unsafe fn new(context: VulkanContext, clear_color: [f32; 4]) -> Result<Self> {
        let pool_info = vk::CommandPoolCreateInfo::default()
            .queue_family_index(context.queue_family_index)
            .flags(vk::CommandPoolCreateFlags::RESET_COMMAND_BUFFER);
        let command_pool = unsafe { context.ash_device.create_command_pool(&pool_info, None)? };

        let color_attachment = vk::AttachmentDescription::default()
            .format(vk::Format::R8G8B8A8_UNORM)
            .samples(vk::SampleCountFlags::TYPE_1)
            .load_op(vk::AttachmentLoadOp::CLEAR)
            .store_op(vk::AttachmentStoreOp::STORE)
            .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
            .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .final_layout(vk::ImageLayout::SHADER_READ_ONLY_OPTIMAL);

        let color_attachment_ref = vk::AttachmentReference {
            attachment: 0,
            layout: vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL,
        };
        let subpass = vk::SubpassDescription::default()
            .pipeline_bind_point(vk::PipelineBindPoint::GRAPHICS)
            .color_attachments(std::slice::from_ref(&color_attachment_ref));

        let dependency = vk::SubpassDependency::default()
            .src_subpass(vk::SUBPASS_EXTERNAL)
            .dst_subpass(0)
            .src_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .dst_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .src_access_mask(vk::AccessFlags::empty())
            .dst_access_mask(vk::AccessFlags::COLOR_ATTACHMENT_WRITE);

        let render_pass_info = vk::RenderPassCreateInfo::default()
            .attachments(std::slice::from_ref(&color_attachment))
            .subpasses(std::slice::from_ref(&subpass))
            .dependencies(std::slice::from_ref(&dependency));

        let render_pass =
            unsafe { context.ash_device.create_render_pass(&render_pass_info, None)? };

        Ok(Self {
            context,
            command_pool,
            render_pass,
            clear_color,
        })
    }

    pub fn render_pass(&self) -> vk::RenderPass {
        self.render_pass
    }

    /// Renders into `texture` by invoking `record_fn` inside an active Vulkan render pass.
    ///
    /// # Safety
    /// `texture` must be backed by Vulkan.
    pub unsafe fn render<F>(
        &mut self,
        texture: &wgpu::Texture,
        width: u32,
        height: u32,
        record_fn: F,
    ) -> Result<()>
    where
        F: FnOnce(vk::CommandBuffer, vk::RenderPass) -> Result<()>,
    {
        if width == 0 || height == 0 {
            return Ok(());
        }

        let hal_texture = unsafe { texture.as_hal::<wgpu_hal::api::Vulkan>() }
            .context("texture is not backed by Vulkan")?;
        let vk_image = unsafe { hal_texture.raw_handle() };

        // 1. Create temporary ImageView for target texture
        let subresource_range = vk::ImageSubresourceRange {
            aspect_mask: vk::ImageAspectFlags::COLOR,
            base_mip_level: 0,
            level_count: 1,
            base_array_layer: 0,
            layer_count: 1,
        };
        let view_info = vk::ImageViewCreateInfo::default()
            .image(vk_image)
            .view_type(vk::ImageViewType::TYPE_2D)
            .format(vk::Format::R8G8B8A8_UNORM)
            .subresource_range(subresource_range);
        let image_view = unsafe { self.context.ash_device.create_image_view(&view_info, None)? };

        // 2. Create Framebuffer
        let framebuffer_info = vk::FramebufferCreateInfo::default()
            .render_pass(self.render_pass)
            .attachments(std::slice::from_ref(&image_view))
            .width(width)
            .height(height)
            .layers(1);
        let framebuffer =
            unsafe { self.context.ash_device.create_framebuffer(&framebuffer_info, None)? };

        // 3. Allocate CommandBuffer
        let alloc_info = vk::CommandBufferAllocateInfo::default()
            .command_pool(self.command_pool)
            .level(vk::CommandBufferLevel::PRIMARY)
            .command_buffer_count(1);
        let cmd = unsafe { self.context.ash_device.allocate_command_buffers(&alloc_info)?[0] };

        // 4. Record draw commands
        let begin_info = vk::CommandBufferBeginInfo::default()
            .flags(vk::CommandBufferUsageFlags::ONE_TIME_SUBMIT);
        unsafe { self.context.ash_device.begin_command_buffer(cmd, &begin_info)? };

        let clear_values = [vk::ClearValue {
            color: vk::ClearColorValue {
                float32: self.clear_color,
            },
        }];
        let render_pass_begin_info = vk::RenderPassBeginInfo::default()
            .render_pass(self.render_pass)
            .framebuffer(framebuffer)
            .render_area(vk::Rect2D {
                offset: vk::Offset2D { x: 0, y: 0 },
                extent: vk::Extent2D { width, height },
            })
            .clear_values(&clear_values);

        unsafe {
            self.context.ash_device.cmd_begin_render_pass(
                cmd,
                &render_pass_begin_info,
                vk::SubpassContents::INLINE,
            );
        }

        let record_res = record_fn(cmd, self.render_pass);

        unsafe {
            self.context.ash_device.cmd_end_render_pass(cmd);
            self.context.ash_device.end_command_buffer(cmd)?;
        }

        // 5. Submit to queue and wait
        if record_res.is_ok() {
            let fence_info = vk::FenceCreateInfo::default();
            let fence = unsafe { self.context.ash_device.create_fence(&fence_info, None)? };

            let submit_info =
                vk::SubmitInfo::default().command_buffers(std::slice::from_ref(&cmd));

            unsafe {
                self.context
                    .ash_device
                    .queue_submit(self.context.queue, &[submit_info], fence)?;
                self.context
                    .ash_device
                    .wait_for_fences(&[fence], true, u64::MAX)?;
                self.context.ash_device.destroy_fence(fence, None);
            }
        }

        // 6. Cleanup temporary resources
        unsafe {
            self.context.ash_device.free_command_buffers(self.command_pool, &[cmd]);
            self.context.ash_device.destroy_framebuffer(framebuffer, None);
            self.context.ash_device.destroy_image_view(image_view, None);
        }

        record_res
    }
}

impl Drop for OffscreenPass {
    fn drop(&mut self) {
        unsafe {
            self.context.ash_device.destroy_render_pass(self.render_pass, None);
            self.context.ash_device.destroy_command_pool(self.command_pool, None);
        }
    }
}
