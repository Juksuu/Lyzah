use crate::texture::Texture;
use std::path::PathBuf;

pub struct Sprite {
    pub texture: Texture,
}

impl Sprite {
    pub fn new(path: PathBuf) -> Self {
        Sprite {
            texture: Texture::new(path),
        }
    }
}
