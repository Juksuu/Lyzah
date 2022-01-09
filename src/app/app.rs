use winit::{
    event::{ElementState, Event, KeyboardInput, VirtualKeyCode, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::{Window, WindowBuilder},
};

use crate::renderer::Renderer;

pub struct Application {
    event_loop: EventLoop<()>,
    window: Window,
    renderer: Renderer,
}

impl Application {
    pub fn new() -> Self {
        let event_loop = EventLoop::new();
        let window = WindowBuilder::new().build(&event_loop).unwrap();

        let renderer = pollster::block_on(Renderer::new(&window));

        Self {
            event_loop,
            window,
            renderer,
        }
    }

    pub fn run(mut self) {
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
                    match self.renderer.render() {
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
                        self.renderer.resize(Some(*physical_size))
                    }
                    WindowEvent::ScaleFactorChanged { new_inner_size, .. } => {
                        self.renderer.resize(Some(**new_inner_size))
                    }
                    _ => {}
                },
                _ => {}
            }
        });
    }
}