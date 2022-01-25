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

    instance: Instance,
    instance_raw: InstanceRaw,
}

impl Sprite {
    pub fn new(path: PathBuf) -> Self {
        let rotation = 0.0;
        let texture = Texture::new(path);
        let position = point2(0.0, 0.0);
        let scale = point2(1.0, 1.0);

        let (instance, instance_raw) = update_instance(&position, &scale, rotation);

        Sprite {
            scale,
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

        (self.instance, self.instance_raw) =
            update_instance(&self.position, &self.scale, self.rotation);
    }

    pub fn set_position(&mut self, x: f32, y: f32) {
        self.position.x = x;
        self.position.y = y;

        (self.instance, self.instance_raw) =
            update_instance(&self.position, &self.scale, self.rotation);
    }

    pub fn set_rotation(&mut self, rotation: f32) {
        self.rotation = rotation;

        (self.instance, self.instance_raw) =
            update_instance(&self.position, &self.scale, self.rotation);
    }
}

fn update_instance(
    position: &Point2<f32>,
    scale: &Point2<f32>,
    rotation: f32,
) -> (Instance, InstanceRaw) {
    let instance = Instance {
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
    let instance_raw = instance.to_raw();

    (instance, instance_raw)
}
