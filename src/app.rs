use crate::{
    instance::InstanceRaw, renderer::Renderer, resources::TextureId, Camera2D, Resources, Sprite,
};
use winit::{
    event::{ElementState, Event, KeyboardInput, VirtualKeyCode, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::{Window, WindowBuilder},
};

pub struct Application {
    event_loop: EventLoop<()>,
    window: Window,
    default_camera: Camera2D,
    pub renderer: Renderer,
    pub resources: Resources,
}

impl Application {
    pub fn new() -> Self {
        let event_loop = EventLoop::new();
        let window = WindowBuilder::new().build(&event_loop).unwrap();

        let renderer = pollster::block_on(Renderer::new(&window));
        let default_camera = Camera2D::new(&renderer);

        let resources = Resources::new();

        Self {
            window,
            renderer,
            resources,
            event_loop,
            default_camera,
        }
    }

    pub fn run<F: 'static>(mut self, mut run_on_update: F)
    where
        F: FnMut() -> Vec<(TextureId, InstanceRaw)>,
    {
        println!("Starting application");

        self.event_loop.run(move |event, _, control_flow| {
            *control_flow = ControlFlow::Poll;
            match event {
                Event::RedrawRequested(window_id) if window_id == self.window.id() => {
                    // let now = Instant::now();
                    // let dt = now - last_render_time;
                    // last_render_time = now;
                    //
                    // state.update(dt);

                    let renderables = run_on_update();

                    match self.renderer.render(
                        renderables,
                        &mut self.resources,
                        &self.default_camera.bind_group,
                    ) {
                        Ok(_) => {}
                        Err(wgpu::SurfaceError::Lost) => self.renderer.resize(None),
                        Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                        Err(e) => eprintln!("{:?}", e),
                    }
                }
                Event::MainEventsCleared => {
                    self.window.request_redraw();
                }
                // Event::DeviceEvent { ref event, .. } => {
                //     state.input(event);
                // }
                Event::WindowEvent {
                    ref event,
                    window_id,
                } if window_id == self.window.id() => match event {
                    WindowEvent::CloseRequested
                    | WindowEvent::KeyboardInput {
                        input:
                            KeyboardInput {
                                state: ElementState::Pressed,
                                virtual_keycode: Some(VirtualKeyCode::Escape),
                                ..
                            },
                        ..
                    } => *control_flow = ControlFlow::Exit,
                    WindowEvent::Resized(physical_size) => {
                        let new_size = *physical_size;
                        self.default_camera
                            .resize(new_size.width, new_size.height, &self.renderer);
                        self.renderer.resize(Some(new_size))
                    }
                    WindowEvent::ScaleFactorChanged { new_inner_size, .. } => {
                        let new_size = **new_inner_size;
                        self.default_camera
                            .resize(new_size.width, new_size.height, &self.renderer);
                        self.renderer.resize(Some(new_size))
                    }
                    _ => {}
                },
                _ => {}
            }
        });
    }
}
