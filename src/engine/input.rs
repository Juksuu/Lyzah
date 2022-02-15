pub use winit::event::VirtualKeyCode;

use cgmath::Point2;
use winit::{
    dpi::{PhysicalPosition, PhysicalSize},
    event::{ButtonId, DeviceEvent, ElementState, KeyboardInput, ModifiersState},
};

pub struct Input {
    pub is_focused: bool,
    pub is_mouse_inside_window: bool,

    pub pressed_keys: Vec<VirtualKeyCode>,
    pub released_keys: Vec<VirtualKeyCode>,
    pub pressed_mouse_buttons: Vec<ButtonId>,
    pub released_mouse_buttons: Vec<ButtonId>,

    pub mouse_delta: Point2<f32>,
    pub mouse_pos: PhysicalPosition<f32>,

    pub modifiers_state: ModifiersState,
}

impl Input {
    pub(crate) fn default() -> Self {
        Input {
            is_focused: false,
            is_mouse_inside_window: false,

            pressed_keys: Vec::new(),
            released_keys: Vec::new(),
            pressed_mouse_buttons: Vec::new(),
            released_mouse_buttons: Vec::new(),

            mouse_delta: Point2 { x: 0.0, y: 0.0 },
            mouse_pos: PhysicalPosition { x: 0.0, y: 0.0 },

            modifiers_state: ModifiersState::default(),
        }
    }

    pub(crate) fn reset_mouse_delta(&mut self) {
        self.mouse_delta.x = 0.0;
        self.mouse_delta.y = 0.0;
    }

    pub(crate) fn process_device_event(&mut self, event: &DeviceEvent) {
        self.released_keys.clear();

        match event {
            DeviceEvent::Key(KeyboardInput {
                virtual_keycode: Some(key),
                state,
                ..
            }) => {
                self.pressed_keys.clear();
                match state {
                    ElementState::Pressed => self.pressed_keys.push(*key),
                    ElementState::Released => {
                        self.released_keys.push(*key);
                        self.pressed_keys
                            .retain(|key| !self.released_keys.contains(key));
                    }
                }
            }
            DeviceEvent::Button { button, state } => {
                self.pressed_mouse_buttons.clear();
                match state {
                    ElementState::Pressed => self.pressed_mouse_buttons.push(*button),
                    ElementState::Released => {
                        self.released_mouse_buttons.push(*button);
                        self.pressed_mouse_buttons
                            .retain(|button| !self.released_mouse_buttons.contains(button));
                    }
                }
            }
            DeviceEvent::MouseMotion { delta } => {
                self.mouse_delta.x = delta.0 as f32;
                self.mouse_delta.y = delta.1 as f32;
            }
            _ => (),
        }
    }

    pub(crate) fn update_mouse_pos(
        &mut self,
        pos: PhysicalPosition<f64>,
        window_size: PhysicalSize<u32>,
    ) {
        let x = pos.x as f32 - (window_size.width / 2) as f32;
        let y = -pos.y as f32 + (window_size.height / 2) as f32;
        self.mouse_pos = PhysicalPosition::new(x, y);
    }

    pub(crate) fn set_mouse_inside_window(&mut self, is_inside: bool) {
        self.is_mouse_inside_window = is_inside;
    }

    pub(crate) fn update_modifiers_state(&mut self, state: ModifiersState) {
        self.modifiers_state = state;
    }

    pub(crate) fn set_focused(&mut self, focused: bool) {
        self.is_focused = focused;
    }
}
