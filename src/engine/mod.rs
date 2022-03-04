pub mod input;
pub mod loader;
pub mod window;

use std::time::Instant;

use self::{loader::Loader, window::Window};
use crate::{
    ecs::{
        prelude::*,
        schedule::{Schedule, Stage, StageLabel},
    },
    engine::input::Input,
    renderer::Renderer,
    Camera2D, Time,
};
use winit::{
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
};

pub struct AppBuilder {
    schedule: Schedule,
}

impl Default for AppBuilder {
    fn default() -> AppBuilder {
        AppBuilder {
            schedule: Schedule::default(),
        }
    }
}

impl AppBuilder {
    pub fn add_stage<S: Stage>(mut self, label: impl StageLabel, stage: S) -> Self {
        self.schedule.add_stage(label, stage);
        self
    }

    pub fn build(self) -> Application {
        Application::new(self.schedule)
    }
}

pub struct Application {
    event_loop: EventLoop<()>,
    default_camera: Camera2D,

    renderer: Renderer,

    schedule: Schedule,

    start_time: Instant,
    last_render_time: Instant,

    pub world: World,
}

impl Application {
    pub fn builder() -> AppBuilder {
        AppBuilder::default()
    }

    pub(crate) fn new(schedule: Schedule) -> Self {
        let event_loop = EventLoop::new();
        let window = Window::new(&event_loop);

        let renderer = pollster::block_on(Renderer::new(&window.winit_window));
        let default_camera = Camera2D::new(&renderer);

        let loader = Loader::new();
        let start_time = Instant::now();
        let last_render_time = start_time;

        let mut world = World::default();

        let time = Time::default();
        let input = Input::default();

        world.insert_resource(time);
        world.insert_resource(input);
        world.insert_resource(window);
        world.insert_resource(loader);

        Self {
            world,
            renderer,
            schedule,
            start_time,
            event_loop,
            default_camera,
            last_render_time,
        }
    }

    pub fn run(mut self) {
        println!("Starting application");

        self.event_loop.run(move |event, _, control_flow| {
            {
                let window = self.world.get_resource::<Window>().unwrap();
                if window.should_quit() {
                    *control_flow = ControlFlow::Exit;
                } else {
                    *control_flow = ControlFlow::Poll;
                }
            }
            match event {
                Event::RedrawRequested(..) => {
                    self.schedule.run(&mut self.world);

                    match self
                        .renderer
                        .render(&mut self.world, &self.default_camera.bind_group)
                    {
                        Ok(_) => {}
                        Err(wgpu::SurfaceError::Lost) => self.renderer.resize(None),
                        Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                        Err(e) => eprintln!("{:?}", e),
                    }

                    let mut time = self.world.get_resource_mut::<Time>().unwrap();

                    // Update time after current loop
                    let now = Instant::now();
                    let dt = now - self.last_render_time;
                    let elapsed = now - self.start_time;
                    self.last_render_time = now;

                    time.elapsed = elapsed;
                    time.delta_time = dt;
                    time.frames += 1;

                    // Reset mouse delta after current update loop
                    let mut input = self.world.get_resource_mut::<Input>().unwrap();
                    input.reset_mouse_delta();
                }
                Event::MainEventsCleared => {
                    let window = self.world.get_resource::<Window>().unwrap();
                    window.winit_window.request_redraw();
                }
                Event::DeviceEvent { ref event, .. } => {
                    let mut input = self.world.get_resource_mut::<Input>().unwrap();
                    input.process_device_event(event);
                }
                Event::WindowEvent { ref event, .. } => match event {
                    WindowEvent::ModifiersChanged(modifiers_state) => {
                        let mut input = self.world.get_resource_mut::<Input>().unwrap();
                        input.update_modifiers_state(*modifiers_state)
                    }
                    WindowEvent::CursorMoved { position, .. } => {
                        let size = {
                            let window = self.world.get_resource::<Window>().unwrap();
                            window.winit_window.inner_size()
                        };

                        let mut input = self.world.get_resource_mut::<Input>().unwrap();
                        input.update_mouse_pos(*position, size)
                    }
                    WindowEvent::Focused(is_focused) => {
                        let mut input = self.world.get_resource_mut::<Input>().unwrap();
                        input.set_focused(*is_focused)
                    }
                    WindowEvent::CursorEntered { .. } => {
                        let mut input = self.world.get_resource_mut::<Input>().unwrap();
                        input.set_mouse_inside_window(true)
                    }
                    WindowEvent::CursorLeft { .. } => {
                        let mut input = self.world.get_resource_mut::<Input>().unwrap();
                        input.set_mouse_inside_window(false)
                    }
                    WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
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
