use cgmath::Point2;

use crate::ecs::prelude::*;
use crate::loader::ResourceId;

#[derive(Clone, Debug, PartialEq, Component)]
pub struct Text {
    pub font_id: ResourceId,
    pub font_size: f32,
    pub text: String,
    pub position: Point2<f32>,
}

impl Text {
    pub fn new(font_id: ResourceId, text: &str) -> Self {
        Text {
            font_id,
            position: Point2 { x: 0.0, y: 0.0 },
            font_size: 32.0,
            text: text.to_string(),
        }
    }
}
