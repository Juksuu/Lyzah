use crate::renderer::Renderer;

#[rustfmt::skip]
pub const OPENGL_TO_WGPU_MATRIX: cgmath::Matrix4<f32> = cgmath::Matrix4::new(
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 0.5, 0.0,
    0.0, 0.0, 0.5, 1.0,
);

#[readonly::make]
pub struct Camera2D {
    width: f32,
    height: f32,

    buffer: wgpu::Buffer,
    uniform: CameraUniform,

    up: cgmath::Vector3<f32>,
    target: cgmath::Point3<f32>,
    position: cgmath::Point3<f32>,

    #[readonly]
    pub bind_group: wgpu::BindGroup,
}

impl Camera2D {
    pub fn new(renderer: &Renderer) -> Self {
        let uniform = CameraUniform::new();
        let buffer = renderer.create_buffer(
            "camera_buffer",
            &[uniform],
            wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        );

        let bind_group = renderer.create_camera_bind_group(&buffer);

        Self {
            width: 0.0,
            height: 0.0,
            buffer,
            uniform,
            bind_group,
            up: cgmath::Vector3::unit_y(),
            target: (0.0, 0.0, 0.0).into(),
            position: (0.0, 0.0, 1.0).into(),
        }
    }

    pub fn set_position(&mut self, position: cgmath::Point3<f32>) {
        self.position = position;
    }

    pub fn resize(&mut self, width: u32, height: u32, renderer: &Renderer) {
        if width > 0 && height > 0 {
            self.width = width as f32;
            self.height = height as f32;

            self.uniform
                .update_view_proj(self.build_view_projection_matrix());

            renderer.write_buffer(&self.buffer, 0, &[self.uniform]);
        }
    }

    pub fn build_view_projection_matrix(&self) -> cgmath::Matrix4<f32> {
        let view = cgmath::Matrix4::look_at_rh(self.position, self.target, self.up);
        let proj = cgmath::ortho(
            -self.width / 2.0,
            self.width / 2.0,
            -self.height / 2.0,
            self.height / 2.0,
            -100.0,
            100.0,
        );

        return OPENGL_TO_WGPU_MATRIX * proj * view;
    }
}

#[repr(C)]
#[derive(Debug, Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct CameraUniform {
    view_proj: [[f32; 4]; 4],
}

impl CameraUniform {
    pub fn new() -> Self {
        use cgmath::SquareMatrix;
        Self {
            view_proj: cgmath::Matrix4::identity().into(),
        }
    }

    pub fn update_view_proj(&mut self, matrix: cgmath::Matrix4<f32>) {
        self.view_proj = matrix.into();
    }
}
