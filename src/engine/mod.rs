pub mod input;

use crate::{engine::input::Input, renderer::Renderer, Camera2D, Resources, Time};
use std::time::Instant;
use winit::{
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::{Window, WindowBuilder},
};

pub struct Application {
    event_loop: EventLoop<()>,
    window: Window,
    default_camera: Camera2D,
    start_time: Instant,
    last_render_time: Instant,
    renderer: Renderer,
    pub resources: Resources,
}

impl Application {
    pub fn new() -> Self {
        let event_loop = EventLoop::new();
        let window = WindowBuilder::new().build(&event_loop).unwrap();

        let renderer = pollster::block_on(Renderer::new(&window));
        let default_camera = Camera2D::new(&renderer);

        let resources = Resources::new();
        let start_time = Instant::now();
        let last_render_time = start_time;

        Self {
            window,
            renderer,
            resources,
            start_time,
            event_loop,
            default_camera,
            last_render_time,
        }
    }

    pub fn run<F: 'static>(
        mut self,
        mut world: legion::World,
        mut resources: legion::Resources,
        mut run_on_update: F,
    ) where
        F: FnMut(&mut legion::World, &mut legion::Resources) -> (),
    {
        println!("Starting application");

        let time = Time::default();
        let input = Input::default();

        resources.insert(time);
        resources.insert(input);

        self.event_loop.run(move |event, _, control_flow| {
            *control_flow = ControlFlow::Poll;
            match event {
                Event::RedrawRequested(window_id) if window_id == self.window.id() => {
                    run_on_update(&mut world, &mut resources);

                    match self.renderer.render(
                        &world,
                        &mut self.resources,
                        &self.default_camera.bind_group,
                    ) {
                        Ok(_) => {}
                        Err(wgpu::SurfaceError::Lost) => self.renderer.resize(None),
                        Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                        Err(e) => eprintln!("{:?}", e),
                    }

                    // Update time after current loop
                    let now = Instant::now();
                    let dt = now - self.last_render_time;
                    let elapsed = now - self.start_time;
                    self.last_render_time = now;

                    {
                        let mut time = resources.get_mut::<Time>().unwrap();
                        time.elapsed = elapsed;
                        time.delta_time = dt;
                    }

                    // Reset mouse delta after current update loop
                    {
                        let mut input = resources.get_mut::<Input>().unwrap();
                        input.reset_mouse_delta();
                    }
                }
                Event::MainEventsCleared => {
                    self.window.request_redraw();
                }
                Event::DeviceEvent { ref event, .. } => {
                    let mut input = resources.get_mut::<Input>().unwrap();
                    input.process_device_event(event);
                }
                Event::WindowEvent {
                    ref event,
                    window_id,
                } => {
                    if window_id == self.window.id() {
                        let mut input = resources.get_mut::<Input>().unwrap();
                        match event {
                            WindowEvent::ModifiersChanged(modifiers_state) => {
                                input.update_modifiers_state(*modifiers_state)
                            }
                            WindowEvent::CursorMoved { position, .. } => {
                                input.update_mouse_pos(*position, self.window.inner_size())
                            }
                            WindowEvent::Focused(is_focused) => input.set_focused(*is_focused),
                            WindowEvent::CursorEntered { .. } => {
                                input.set_mouse_inside_window(true)
                            }
                            WindowEvent::CursorLeft { .. } => input.set_mouse_inside_window(false),
                            WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
                            WindowEvent::Resized(physical_size) => {
                                let new_size = *physical_size;
                                self.default_camera.resize(
                                    new_size.width,
                                    new_size.height,
                                    &self.renderer,
                                );
                                self.renderer.resize(Some(new_size))
                            }
                            WindowEvent::ScaleFactorChanged { new_inner_size, .. } => {
                                let new_size = **new_inner_size;
                                self.default_camera.resize(
                                    new_size.width,
                                    new_size.height,
                                    &self.renderer,
                                );
                                self.renderer.resize(Some(new_size))
                            }
                            _ => {}
                        }
                    }
                }
                _ => {}
            }
        });
    }
}
