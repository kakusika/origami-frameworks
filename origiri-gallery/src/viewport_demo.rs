use std::time::Instant;

use origiri_viewport::ViewportBridge;
use slint::Image;

const SHADER: &str = r#"
struct Uniforms {
    time: f32,
    aspect: f32,
    pad0: f32,
    pad1: f32,
};
@group(0) @binding(0) var<uniform> u: Uniforms;

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOutput {
    var positions = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 0.65),
        vec2<f32>(-0.6, -0.45),
        vec2<f32>(0.6, -0.45)
    );
    var colors = array<vec4<f32>, 3>(
        vec4<f32>(0.95, 0.35, 0.45, 1.0),
        vec4<f32>(0.35, 0.85, 0.55, 1.0),
        vec4<f32>(0.40, 0.55, 0.95, 1.0)
    );
    let p = positions[idx];
    let angle = u.time;
    let cos_a = cos(angle);
    let sin_a = sin(angle);
    let rot = vec2<f32>(
        p.x * cos_a - p.y * sin_a,
        p.x * sin_a + p.y * cos_a
    );
    var out: VertexOutput;
    out.pos = vec4<f32>(rot.x / u.aspect, rot.y, 0.0, 1.0);
    out.color = colors[idx];
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}
"#;

struct GpuPipeline {
    pipeline: wgpu::RenderPipeline,
    uniform_buf: wgpu::Buffer,
    bind_group: wgpu::BindGroup,
}

pub struct ViewportDemo {
    bridge: ViewportBridge,
    gpu: Option<GpuPipeline>,
    time: f32,
    speed: f32,
    is_paused: bool,
    last_frame: Instant,
    fps_timer: Instant,
    frame_count: u32,
}

impl ViewportDemo {
    pub fn new() -> Self {
        Self {
            bridge: ViewportBridge::new(640, 480),
            gpu: None,
            time: 0.0,
            speed: 1.0,
            is_paused: false,
            last_frame: Instant::now(),
            fps_timer: Instant::now(),
            frame_count: 0,
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.bridge.resize(width, height);
    }

    pub fn toggle_pause(&mut self) -> bool {
        self.is_paused = !self.is_paused;
        self.is_paused
    }

    pub fn set_speed(&mut self, speed: f32) {
        self.speed = speed.max(0.0);
    }

    pub fn render(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
    ) -> Option<(Image, u32, u32, Option<f32>)> {
        let width = self.bridge.width();
        let height = self.bridge.height();
        self.bridge.ensure_texture(device).ok()?;

        if self.gpu.is_none() {
            let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("viewport_demo_shader"),
                source: wgpu::ShaderSource::Wgsl(SHADER.into()),
            });

            let uniform_buf = device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("viewport_demo_uniforms"),
                size: 16,
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            });

            let bind_group_layout =
                device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                    label: Some("viewport_demo_bgl"),
                    entries: &[wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::VERTEX,
                        ty: wgpu::BindingType::Buffer {
                            ty: wgpu::BufferBindingType::Uniform,
                            has_dynamic_offset: false,
                            min_binding_size: None,
                        },
                        count: None,
                    }],
                });

            let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("viewport_demo_bg"),
                layout: &bind_group_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buf.as_entire_binding(),
                }],
            });

            let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("viewport_demo_pipeline_layout"),
                bind_group_layouts: &[Some(&bind_group_layout)],
                immediate_size: 0,
            });

            let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some("viewport_demo_pipeline"),
                layout: Some(&pipeline_layout),
                vertex: wgpu::VertexState {
                    module: &module,
                    entry_point: Some("vs_main"),
                    compilation_options: Default::default(),
                    buffers: &[],
                },
                fragment: Some(wgpu::FragmentState {
                    module: &module,
                    entry_point: Some("fs_main"),
                    compilation_options: Default::default(),
                    targets: &[Some(wgpu::ColorTargetState {
                        format: wgpu::TextureFormat::Rgba8Unorm,
                        blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                        write_mask: wgpu::ColorWrites::ALL,
                    })],
                }),
                primitive: wgpu::PrimitiveState {
                    topology: wgpu::PrimitiveTopology::TriangleList,
                    ..Default::default()
                },
                depth_stencil: None,
                multisample: wgpu::MultisampleState::default(),
                multiview_mask: None,
                cache: None,
            });

            self.gpu = Some(GpuPipeline {
                pipeline,
                uniform_buf,
                bind_group,
            });
        }

        let now = Instant::now();
        let dt = now.duration_since(self.last_frame).as_secs_f32();
        self.last_frame = now;

        if !self.is_paused {
            self.time += dt * self.speed * 2.0;
        }

        let aspect = (width as f32 / height.max(1) as f32).max(0.01);
        let uniforms: [f32; 4] = [self.time, aspect, 0.0, 0.0];

        let gpu = self.gpu.as_ref()?;
        queue.write_buffer(&gpu.uniform_buf, 0, bytemuck_cast(&uniforms));

        let view = self
            .bridge
            .texture()?
            .create_view(&wgpu::TextureViewDescriptor::default());
        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("viewport_demo_encoder"),
        });

        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("viewport_demo_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    depth_slice: None,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color {
                            r: 0.05,
                            g: 0.06,
                            b: 0.08,
                            a: 1.0,
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
                multiview_mask: None,
            });

            pass.set_pipeline(&gpu.pipeline);
            pass.set_bind_group(0, &gpu.bind_group, &[]);
            pass.draw(0..3, 0..1);
        }

        queue.submit([encoder.finish()]);

        // FPS calculation
        self.frame_count += 1;
        let mut fps_update = None;
        let elapsed = now.duration_since(self.fps_timer).as_secs_f32();
        if elapsed >= 0.5 {
            let fps = self.frame_count as f32 / elapsed;
            fps_update = Some(fps);
            self.frame_count = 0;
            self.fps_timer = now;
        }

        let img = self.bridge.to_slint_image().ok()?;
        Some((img, width, height, fps_update))
    }
}

fn bytemuck_cast<T>(v: &[T]) -> &[u8] {
    unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u8, std::mem::size_of_val(v)) }
}
