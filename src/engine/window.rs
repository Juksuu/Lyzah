use std::sync::{mpsc, Arc, Mutex};

use winit::{
    event_loop::EventLoop,
    window::{self, Fullscreen},
};

pub enum WindowMode {
    Fullscreen,
    Windowed,
}

pub struct Window {
    pub(super) winit_window: window::Window,
    pub(super) quit_sender: Arc<Mutex<mpsc::Sender<bool>>>,
    pub(super) quit_receiver: Arc<Mutex<mpsc::Receiver<bool>>>,
}

impl Window {
    pub(crate) fn new(event_loop: &EventLoop<()>) -> Self {
        let (quit_sender, quit_receiver) = mpsc::channel();
        Self {
            quit_sender: Arc::new(Mutex::new(quit_sender)),
            quit_receiver: Arc::new(Mutex::new(quit_receiver)),
            winit_window: window::WindowBuilder::new().build(&event_loop).unwrap(),
        }
    }

    pub(crate) fn should_quit(&self) -> bool {
        self.quit_receiver
            .lock()
            .unwrap()
            .try_recv()
            .unwrap_or(false)
    }

    pub fn set_window_mode(&self, mode: WindowMode) {
        match mode {
            WindowMode::Fullscreen => self
                .winit_window
                .set_fullscreen(Some(Fullscreen::Borderless(None))),
            WindowMode::Windowed => self.winit_window.set_fullscreen(None),
        }
    }

    pub fn close(&self) {
        self.quit_sender
            .lock()
            .unwrap()
            .send(true)
            .expect("Could not send quit event");
    }
}
