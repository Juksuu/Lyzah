pub use winit::event::VirtualKeyCode;
use winit::event::{DeviceEvent, ElementState, KeyboardInput, ModifiersState};

pub struct Input {
    pub pressed_keys: Vec<VirtualKeyCode>,
    pub released_keys: Vec<VirtualKeyCode>,
    pub modifiers_state: ModifiersState,
    pub is_focused: bool,
}

impl Input {
    pub(crate) fn default() -> Self {
        Input {
            pressed_keys: Vec::new(),
            released_keys: Vec::new(),
            modifiers_state: ModifiersState::default(),
            is_focused: false,
        }
    }

    pub(crate) fn process_device_event(&mut self, event: &DeviceEvent) {
        self.released_keys.clear();
        match event {
            DeviceEvent::Key(KeyboardInput {
                virtual_keycode: Some(key),
                state,
                ..
            }) => match state {
                ElementState::Pressed => self.pressed_keys.push(*key),
                ElementState::Released => {
                    self.released_keys.push(*key);
                    self.pressed_keys
                        .retain(|key| !self.released_keys.contains(key));
                }
            },
            _ => (),
        }
    }

    pub(crate) fn set_modifiers_state(&mut self, state: ModifiersState) {
        self.modifiers_state = state;
    }

    pub(crate) fn set_focused(&mut self, focused: bool) {
        self.is_focused = focused;
    }
}
