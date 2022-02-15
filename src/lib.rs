use std::time::Duration;

mod engine;
mod renderer;

mod camera;
mod resources;
mod sprite;
mod texture;

pub use camera::Camera2D;
pub use engine::Application;
pub use resources::Resources;
pub use sprite::Sprite;

pub struct Time {
    pub elapsed: Duration,
    pub delta_time: Duration,
}

impl Time {
    pub fn default() -> Self {
        Time {
            elapsed: Duration::from_secs(0),
            delta_time: Duration::from_secs(0),
        }
    }
}
