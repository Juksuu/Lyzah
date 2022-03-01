use crate::{
    ecs::prelude::*,
    loader::ResourceId,
    renderer::instance::{Instance, InstanceRaw},
};
use cgmath::*;
use wgpu::Extent3d;

#[readonly::make]
#[derive(Clone, Debug, PartialEq, Component)]
pub struct Sprite {
    pub texture_id: ResourceId,
    #[readonly]
    pub rotation: f32,
    #[readonly]
    pub position: Point2<f32>,
    #[readonly]
    pub scale: Point2<f32>,
    #[readonly]
    pub anchor: Point2<f32>,

    instance: Instance,
}

impl Sprite {
    pub fn new(texture_id: ResourceId) -> Self {
        let rotation = 0.0;
        let position = point2(0.0, 0.0);
        let scale = point2(1.0, 1.0);
        let anchor = point2(0.0, 0.0);

        Sprite {
            scale,
            anchor,
            texture_id,
            position,
            rotation,
            instance: Instance::default(),
        }
    }

    pub fn set_scale(&mut self, x: f32, y: f32) {
        self.scale.x = x;
        self.scale.y = y;

        self.instance.scale.x = self.scale.x;
        self.instance.scale.y = self.scale.y;
    }

    pub fn set_position(&mut self, x: f32, y: f32) {
        self.position.x = x;
        self.position.y = y;

        self.instance.position.x = self.position.x;
        self.instance.position.y = self.position.y;
    }

    pub fn set_rotation(&mut self, rotation: f32) {
        self.rotation = rotation;

        self.instance.rotation = Quaternion::from_angle_z(cgmath::Rad(self.rotation));
    }

    pub fn set_anchor(&mut self, x: f32, y: f32) {
        self.anchor.x = x;
        self.anchor.y = y;

        self.instance.anchor.x = self.anchor.x;
        self.instance.anchor.y = self.anchor.y;
    }

    pub(crate) fn get_raw_instance(&self, size: &Extent3d) -> InstanceRaw {
        self.instance.to_raw(size)
    }
}
