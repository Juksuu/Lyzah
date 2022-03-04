pub(crate) mod instance;
pub(crate) mod vertex;

use self::vertex::Vertex;

use crate::{ecs::prelude::*, loader::Loader, Sprite, Time};
use image::{GenericImageView, ImageBuffer, Rgba};
use std::{collections::HashMap, iter::once, num::NonZeroU32};
use wgpu::*;
use wgpu_glyph::{
    ab_glyph::{self, FontArc},
    GlyphBrushBuilder, Section, Text,
};
use winit::{dpi::PhysicalSize, window::Window};

pub(crate) struct TextureData {
    bind_group: BindGroup,
    vertex_buffer: Buffer,
    index_buffer: Buffer,
    num_indices: u32,
}

pub(crate) struct RenderData {
    texture_data: TextureData,
    instances: Vec<instance::InstanceRaw>,
}

pub(crate) struct Renderer {
    surface: Surface,
    device: Device,
    queue: Queue,
    config: SurfaceConfiguration,
    default_font: FontArc,
    clear_color: Color,
    staging_belt: util::StagingBelt,
    render_pipeline: RenderPipeline,
    render_data: HashMap<String, RenderData>,
    instance_buffers: HashMap<String, Buffer>,
}

impl Renderer {
    pub async fn new(window: &Window) -> Self {
        let size = window.inner_size();
        let instance = Instance::new(Backends::all());
        let surface = unsafe { instance.create_surface(&window) };

        let adapter = instance
            .request_adapter(&RequestAdapterOptions {
                power_preference: PowerPreference::default(),
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await
            .unwrap();

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    features: Features::empty(),
                    limits: Limits::default(),
                    label: None,
                },
                None,
            )
            .await
            .unwrap();

        let config = SurfaceConfiguration {
            usage: TextureUsages::RENDER_ATTACHMENT,
            format: surface.get_preferred_format(&adapter).unwrap(),
            width: size.width,
            height: size.height,
            present_mode: wgpu::PresentMode::Immediate,
        };
        surface.configure(&device, &config);

        let camera_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
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
                label: Some("camera_bind_group_layout"),
            });

        let texture_bind_group_layout =
            device.create_bind_group_layout(&BindGroupLayoutDescriptor {
                label: Some("texture_bind_group_layout"),
                entries: &[
                    BindGroupLayoutEntry {
                        binding: 0,
                        visibility: ShaderStages::FRAGMENT,
                        ty: BindingType::Texture {
                            multisampled: false,
                            view_dimension: TextureViewDimension::D2,
                            sample_type: TextureSampleType::Float { filterable: true },
                        },
                        count: None,
                    },
                    BindGroupLayoutEntry {
                        binding: 1,
                        visibility: ShaderStages::FRAGMENT,
                        ty: BindingType::Sampler(SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
            });

        let render_pipeline = {
            let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("Render Pipeline Layout"),
                bind_group_layouts: &[&texture_bind_group_layout, &camera_bind_group_layout],
                push_constant_ranges: &[],
            });

            let shader = wgpu::ShaderModuleDescriptor {
                label: Some("Shader"),
                source: wgpu::ShaderSource::Wgsl(std::borrow::Cow::Borrowed(include_str!(
                    "../../resources/default.wgsl"
                ))),
            };

            create_render_pipeline(
                &device,
                &layout,
                config.format,
                None,
                &[Vertex::desc(), instance::InstanceRaw::desc()],
                shader,
            )
        };

        let default_font = ab_glyph::FontArc::try_from_slice(include_bytes!(
            "../../resources/Inconsolata-Regular.ttf"
        ))
        .unwrap();
        let staging_belt = util::StagingBelt::new(1024);

        Self {
            surface,
            device,
            queue,
            config,
            default_font,
            staging_belt,
            render_pipeline,
            clear_color: Color::BLACK,
            render_data: HashMap::new(),
            instance_buffers: HashMap::new(),
        }
    }

    pub fn resize(&mut self, new_size: Option<PhysicalSize<u32>>) {
        let new_size = new_size.unwrap_or(PhysicalSize {
            width: self.config.width,
            height: self.config.height,
        });
        if new_size.width > 0 && new_size.height > 0 {
            self.config.width = new_size.width;
            self.config.height = new_size.height;
            self.surface.configure(&self.device, &self.config);
        }
    }

    pub fn render(
        &mut self,
        world: &mut World,
        camera_bind_group: &BindGroup,
    ) -> Result<(), SurfaceError> {
        let output = self.surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&TextureViewDescriptor::default());

        let mut encoder = self
            .device
            .create_command_encoder(&CommandEncoderDescriptor {
                label: Some("Render Encoder"),
            });

        self.render_data.clear();
        self.instance_buffers.clear();

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Render Pass"),
                color_attachments: &[wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(self.clear_color),
                        store: true,
                    },
                }],
                depth_stencil_attachment: None,
            });

            render_pass.set_pipeline(&self.render_pipeline);

            // Sprite handling
            {
                let mut query = world.query::<&Sprite>();

                let loader = world.get_resource::<Loader>().unwrap();
                for sprite in query.iter(world) {
                    let texture = loader.get_texture_by_id(sprite.texture_id);
                    match self.render_data.get_mut(&texture.name) {
                        Some(data) => {
                            data.instances.push(sprite.get_raw_instance(&texture.size));
                        }
                        None => {
                            let rgba = texture.image.to_rgba8();
                            let dimensions = texture.image.dimensions();
                            let bind_group = self.create_texture_bind_group(
                                &texture.name,
                                texture.size,
                                &rgba,
                                dimensions,
                            );

                            let vertex_buffer = self.create_buffer(
                                "vertex_buffer",
                                texture.vertices.as_slice(),
                                BufferUsages::VERTEX,
                            );
                            let index_buffer = self.create_buffer(
                                "index_buffer",
                                texture.indices.as_slice(),
                                BufferUsages::INDEX,
                            );

                            let mut instances = Vec::new();
                            instances.push(sprite.get_raw_instance(&texture.size));

                            self.render_data.insert(
                                texture.name.clone(),
                                RenderData {
                                    texture_data: TextureData {
                                        bind_group,
                                        vertex_buffer,
                                        index_buffer,
                                        num_indices: texture.indices.len() as u32,
                                    },
                                    instances,
                                },
                            );
                        }
                    }
                }
            }

            for (key, data) in self.render_data.iter() {
                let instance_buffer = self.create_buffer(
                    "Instance buffer",
                    data.instances.as_slice(),
                    BufferUsages::VERTEX,
                );
                self.instance_buffers.insert(key.clone(), instance_buffer);
            }

            for (key, data) in self.render_data.iter() {
                render_pass.set_bind_group(0, &data.texture_data.bind_group, &[]);
                render_pass.set_bind_group(1, camera_bind_group, &[]);
                render_pass.set_vertex_buffer(0, data.texture_data.vertex_buffer.slice(..));
                render_pass.set_vertex_buffer(1, self.instance_buffers.get(key).unwrap().slice(..));
                render_pass.set_index_buffer(
                    data.texture_data.index_buffer.slice(..),
                    IndexFormat::Uint16,
                );
                render_pass.draw_indexed(
                    0..data.texture_data.num_indices,
                    0,
                    0..data.instances.len() as u32,
                );
            }
        }

        let time = world.get_resource::<Time>().unwrap();

        // debug stuff
        {
            if time.frames != 0 {
                let mut glyph_brush = GlyphBrushBuilder::using_font(&self.default_font)
                    .build(&self.device, TextureFormat::Bgra8UnormSrgb);

                let fps = 1.0 / time.delta_time.as_secs_f32();
                glyph_brush.queue(Section {
                    screen_position: (20.0, 10.0),
                    bounds: (self.config.width as f32, self.config.height as f32),
                    text: vec![Text::new(&format!("{:.0} fps", fps))
                        .with_color([1.0, 1.0, 1.0, 1.0])
                        .with_scale(20.0)],
                    ..Section::default()
                });

                let frame_time = time.delta_time.as_micros() as f32 / 1000.0;
                glyph_brush.queue(Section {
                    screen_position: (20.0, 25.0),
                    bounds: (self.config.width as f32, self.config.height as f32),
                    text: vec![Text::new(&format!("{:.2} ms", frame_time))
                        .with_color([1.0, 1.0, 1.0, 1.0])
                        .with_scale(20.0)],
                    ..Section::default()
                });

                // Draw the text!
                glyph_brush
                    .draw_queued(
                        &self.device,
                        &mut self.staging_belt,
                        &mut encoder,
                        &view,
                        self.config.width,
                        self.config.height,
                    )
                    .expect("Draw queued");
            }
        }

        self.staging_belt.finish();
        self.queue.submit(once(encoder.finish()));
        output.present();

        Ok(())
    }

    pub fn create_camera_bind_group(&self, buffer: &Buffer) -> BindGroup {
        self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            layout: &self.render_pipeline.get_bind_group_layout(1),
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: buffer.as_entire_binding(),
            }],
            label: Some("camera_bind_group"),
        })
    }

    pub fn create_texture_bind_group(
        &self,
        name: &str,
        texture_size: wgpu::Extent3d,
        rgba: &ImageBuffer<Rgba<u8>, Vec<u8>>,
        dimension: (u32, u32),
    ) -> BindGroup {
        let texture = self.device.create_texture(&TextureDescriptor {
            size: texture_size,
            mip_level_count: 1,
            sample_count: 1,
            dimension: TextureDimension::D2,
            format: TextureFormat::Rgba8UnormSrgb,
            usage: TextureUsages::TEXTURE_BINDING | TextureUsages::COPY_DST,
            label: Some(name),
        });

        self.queue.write_texture(
            ImageCopyTexture {
                texture: &texture,
                mip_level: 0,
                origin: Origin3d::ZERO,
                aspect: TextureAspect::All,
            },
            rgba,
            ImageDataLayout {
                offset: 0,
                bytes_per_row: NonZeroU32::new(4 * dimension.0),
                rows_per_image: NonZeroU32::new(dimension.1),
            },
            texture_size,
        );

        let texture_view = texture.create_view(&TextureViewDescriptor::default());
        let sampler = self.device.create_sampler(&SamplerDescriptor {
            address_mode_u: AddressMode::ClampToEdge,
            address_mode_v: AddressMode::ClampToEdge,
            address_mode_w: AddressMode::ClampToEdge,
            mag_filter: FilterMode::Linear,
            min_filter: FilterMode::Nearest,
            mipmap_filter: FilterMode::Nearest,
            ..Default::default()
        });

        self.device.create_bind_group(&BindGroupDescriptor {
            layout: &self.render_pipeline.get_bind_group_layout(0),
            entries: &[
                BindGroupEntry {
                    binding: 0,
                    resource: BindingResource::TextureView(&texture_view),
                },
                BindGroupEntry {
                    binding: 1,
                    resource: BindingResource::Sampler(&sampler),
                },
            ],
            label: Some(name),
        })
    }

    pub fn create_buffer<T>(&self, name: &str, data: &[T], usage: BufferUsages) -> wgpu::Buffer
    where
        T: bytemuck::Pod,
    {
        util::DeviceExt::create_buffer_init(
            &self.device,
            &util::BufferInitDescriptor {
                label: Some(name),
                contents: bytemuck::cast_slice(data),
                usage,
            },
        )
    }

    pub fn write_buffer<T>(&self, buffer: &Buffer, offset: u64, data: &[T])
    where
        T: bytemuck::Pod,
    {
        self.queue
            .write_buffer(buffer, offset, bytemuck::cast_slice(data));
    }
}

fn create_render_pipeline(
    device: &wgpu::Device,
    layout: &wgpu::PipelineLayout,
    color_format: wgpu::TextureFormat,
    depth_format: Option<wgpu::TextureFormat>,
    vertex_layouts: &[wgpu::VertexBufferLayout],
    shader: wgpu::ShaderModuleDescriptor,
) -> wgpu::RenderPipeline {
    let shader = device.create_shader_module(&shader);

    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("Render Pipeline"),
        layout: Some(layout),
        vertex: wgpu::VertexState {
            module: &shader,
            entry_point: "vs_main",
            buffers: vertex_layouts,
        },
        fragment: Some(wgpu::FragmentState {
            module: &shader,
            entry_point: "fs_main",
            targets: &[wgpu::ColorTargetState {
                format: color_format,
                blend: Some(wgpu::BlendState::REPLACE),
                write_mask: wgpu::ColorWrites::ALL,
            }],
        }),
        primitive: wgpu::PrimitiveState {
            topology: wgpu::PrimitiveTopology::TriangleList,
            strip_index_format: None,
            front_face: wgpu::FrontFace::Ccw,
            cull_mode: Some(wgpu::Face::Back),
            unclipped_depth: false,
            polygon_mode: wgpu::PolygonMode::Fill,
            conservative: false,
        },
        depth_stencil: depth_format.map(|format| wgpu::DepthStencilState {
            format,
            depth_write_enabled: true,
            depth_compare: wgpu::CompareFunction::Less,
            stencil: wgpu::StencilState::default(),
            bias: wgpu::DepthBiasState::default(),
        }),
        multisample: wgpu::MultisampleState {
            count: 1,
            mask: !0,
            alpha_to_coverage_enabled: false,
        },
        multiview: None,
    })
}
