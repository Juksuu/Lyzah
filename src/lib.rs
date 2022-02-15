use std::time::Duration;

mod app;
mod camera;
mod instance;
mod renderer;
mod resources;
mod sprite;
mod texture;
mod vertex;

pub use app::Application;
pub use camera::Camera2D;
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
