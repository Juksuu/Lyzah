use std::time::Duration;

mod engine;
mod renderer;

mod camera;
mod sprite;
mod text;
mod texture;

pub use camera::Camera2D;
pub use engine::input;
pub use engine::loader;
pub use engine::window;
pub use engine::Application;
pub use sprite::Sprite;
pub use text::Text;
pub use texture::Texture;

pub mod ecs {
    pub use bevy_ecs::*;
}

#[derive(Default)]
pub struct Time {
    pub elapsed: Duration,
    pub delta_time: Duration,
    pub frames: u32,
}
