use winit::{
    event::{ElementState, Event, KeyboardInput, VirtualKeyCode, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::{Window, WindowBuilder},
};

pub struct Application {
    event_loop: EventLoop<()>,
    window: Window,
}

impl Application {
    pub fn new() -> Self {
        let event_loop = EventLoop::new();
        let window = WindowBuilder::new().build(&event_loop).unwrap();

        Self { event_loop, window }
    }

    pub fn run(self) {
        println!("Starting application");

        self.event_loop.run(move |event, _, control_flow| {
            *control_flow = ControlFlow::Poll;
            match event {
                // Event::RedrawRequested(window_id) if window_id == self.window.id() => {
                //     let now = Instant::now();
                //     let dt = now - last_render_time;
                //     last_render_time = now;
                //
                //     state.update(dt);
                //     match state.render() {
                //         Ok(_) => {}
                //         Err(wgpu::SurfaceError::Lost) => state.resize(state.size),
                //         Err(wgpu::SurfaceError::OutOfMemory) => *control_flow = ControlFlow::Exit,
                //         Err(e) => eprintln!("{:?}", e),
                //     }
                // }
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
                    // WindowEvent::Resized(physical_size) => state.resize(*physical_size),
                    // WindowEvent::ScaleFactorChanged { new_inner_size, .. } => {
                    //     state.resize(**new_inner_size)
                    // }
                    _ => {}
                },
                _ => {}
            }
        });
    }
}
