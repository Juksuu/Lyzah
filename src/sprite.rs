use crate::{instance::Point2D, texture::Texture};
use std::path::PathBuf;

#[readonly::make]
pub struct Sprite {
    pub texture: Texture,
    #[readonly]
    pub rotation: f32,
    #[readonly]
    pub position: Point2D,
}

impl Sprite {
    pub fn new(path: PathBuf) -> Self {
        Sprite {
            texture: Texture::new(path),
            position: Point2D { x: 0.0, y: 0.0 },
            rotation: 0.0,
        }
    }

    pub fn set_position(&mut self, x: f32, y: f32) {
        self.position.x = x;
        self.position.y = y;
    }

    pub fn set_rotation(&mut self, rotation: f32) {
        self.rotation = rotation;
    }
}
