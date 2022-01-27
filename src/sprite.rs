use crate::{
    instance::{Instance, InstanceRaw},
    texture::Texture,
};
use cgmath::*;
use std::path::PathBuf;

#[readonly::make]
pub struct Sprite {
    pub texture: Texture,
    #[readonly]
    pub rotation: f32,
    #[readonly]
    pub position: Point2<f32>,
    #[readonly]
    pub scale: Point2<f32>,
    #[readonly]
    pub anchor: Point2<f32>,

    instance: Instance,
    instance_raw: InstanceRaw,
}

impl Sprite {
    pub fn new(path: PathBuf) -> Self {
        let rotation = 0.0;
        let texture = Texture::new(path);
        let position = point2(0.0, 0.0);
        let scale = point2(1.0, 1.0);
        let anchor = point2(0.0, 0.0);

        let (instance, instance_raw) =
            update_instance(&anchor, &position, &scale, rotation, &texture.size);

        Sprite {
            scale,
            anchor,
            texture,
            position,
            rotation,

            instance,
            instance_raw,
        }
    }

    pub fn get_raw_instance(&self) -> InstanceRaw {
        self.instance_raw
    }

    pub fn set_scale(&mut self, x: f32, y: f32) {
        self.scale.x = x;
        self.scale.y = y;

        (self.instance, self.instance_raw) = update_instance(
            &self.anchor,
            &self.position,
            &self.scale,
            self.rotation,
            &self.texture.size,
        );
    }

    pub fn set_position(&mut self, x: f32, y: f32) {
        self.position.x = x;
        self.position.y = y;

        (self.instance, self.instance_raw) = update_instance(
            &self.anchor,
            &self.position,
            &self.scale,
            self.rotation,
            &self.texture.size,
        );
    }

    pub fn set_rotation(&mut self, rotation: f32) {
        self.rotation = rotation;

        (self.instance, self.instance_raw) = update_instance(
            &self.anchor,
            &self.position,
            &self.scale,
            self.rotation,
            &self.texture.size,
        );
    }

    pub fn set_anchor(&mut self, x: f32, y: f32) {
        self.anchor.x = x;
        self.anchor.y = y;

        (self.instance, self.instance_raw) = update_instance(
            &self.anchor,
            &self.position,
            &self.scale,
            self.rotation,
            &self.texture.size,
        );
    }
}

fn update_instance(
    anchor: &Point2<f32>,
    position: &Point2<f32>,
    scale: &Point2<f32>,
    rotation: f32,
    size: &wgpu::Extent3d,
) -> (Instance, InstanceRaw) {
    let instance = Instance {
        anchor: Vector3 {
            x: anchor.x,
            y: anchor.y,
            z: 0.0,
        },
        position: Vector3 {
            x: position.x,
            y: position.y,
            z: 0.0,
        },
        scale: Vector3 {
            x: scale.x,
            y: scale.y,
            z: 1.0,
        },
        rotation: Quaternion::from_angle_z(cgmath::Rad(rotation)),
    };
    let instance_raw = instance.to_raw(size);

    (instance, instance_raw)
}
