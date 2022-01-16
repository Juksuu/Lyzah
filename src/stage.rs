use crate::Sprite;

pub struct Stage {
    pub children: Vec<Sprite>,
}

impl Stage {
    pub fn new() -> Self {
        Self {
            children: Vec::new(),
        }
    }
}
