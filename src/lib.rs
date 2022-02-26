use std::time::Duration;

mod engine;
mod renderer;

mod camera;
mod sprite;
mod texture;

pub use camera::Camera2D;
pub use engine::input;
pub use engine::loader;
pub use engine::Application;
pub use sprite::Sprite;
pub use texture::Texture;
pub use winit::window::Window;

#[derive(Default)]
pub struct Time {
    pub elapsed: Duration,
    pub delta_time: Duration,
}
