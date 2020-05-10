use winit::event::{Event};
use winit::event_loop::{EventLoop};

pub struct GameWindow {
    pub width: u32,
    pub height: u32,
    pub title: String,
    _window: Option<winit::window::Window>,
    _event_loop: Option<EventLoop<()>>
}

impl GameWindow {
    pub fn new(w: u32, h: u32, title: &str) -> GameWindow {
        GameWindow {
            width: w,
            height: h,
            title: title.to_string(),
            _window: None,
            _event_loop: None,
        }
    }

    pub fn init(&mut self, event_loop: EventLoop<()>) {
        self._window = Some(self.create_window(&event_loop));
        self._event_loop = Some(event_loop);
    }

    fn create_window(&self, event_loop: &EventLoop<()>) -> winit::window::Window {
        winit::window::WindowBuilder::new()
            .with_title(&self.title)
            .with_inner_size(winit::dpi::LogicalSize::new(self.width, self.height))
            .build(event_loop)
            .expect("Failed to initialize window.")
    }

    pub fn main_loop(self) {
        match self._event_loop {
            | Some(event_loop) => {
                event_loop.run(move |event, _, control_flow| {
                match event {
                    | Event::WindowEvent { event, .. } => {
                        println!("Window event {:?}", event);
                    },
                    _ => ()
                }
                });
            },
            | None => println!("Cannot start unassigned event loop")
        }
    }
}

pub fn create_window_event_loop() -> winit::event_loop::EventLoop<()> {
    winit::event_loop::EventLoop::new()
}
