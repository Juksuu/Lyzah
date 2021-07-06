extern crate sdl2;

use sdl2::event::Event;
use sdl2::keyboard::Keycode;
use sdl2::pixels::Color;
use sdl2::render::RendererInfo;
use std::time::Duration;

#[derive(PartialEq)]
enum RunState {
    Running,
    Stopped,
}

pub struct GameWindowContext {
    sdl_context: sdl2::Sdl,
    canvas: Option<sdl2::render::WindowCanvas>,
    run_state: RunState,
}

impl GameWindowContext {
    pub fn new() -> Self {
        let sdl_context = sdl2::init().unwrap();

        Self {
            sdl_context,
            canvas: None,
            run_state: RunState::Stopped,
        }
    }

    pub fn init(mut self) -> Self {
        let video_subsystem = self.sdl_context.video().unwrap();

        // Ignore any errors that might happen with window creation, for now
        let window = video_subsystem.window("Lyzah", 800, 600).build().unwrap();
        let mut canvas = window.into_canvas().build().unwrap();

        canvas.set_draw_color(Color::RGB(0, 255, 255));
        canvas.clear();
        canvas.present();

        self.canvas = Some(canvas);
        self.run_state = RunState::Running;
        self
    }

    pub fn get_info(&self) -> Option<RendererInfo> {
        match &self.canvas {
            Some(canvas) => Some(canvas.info()),
            _ => None,
        }
    }

    pub fn run_render_loop(self) {
        let mut event_pump = self.sdl_context.event_pump().unwrap();
        let mut canvas = self.canvas.unwrap();

        let mut i = 0;
        'mainloop: loop {
            i = (i + 1) % 255;
            canvas.set_draw_color(Color::RGB(i, 64, 255 - i));
            canvas.clear();

            for event in event_pump.poll_iter() {
                match event {
                    Event::Quit { .. }
                    | Event::KeyDown {
                        keycode: Some(Keycode::Escape),
                        ..
                    } => {
                        break 'mainloop;
                    }
                    _ => {}
                }
            }

            canvas.present();
            std::thread::sleep(Duration::new(0, 1_000_000_000u32 / 60));
        }
    }
}
