use crate::{
    renderer::instance::{Instance, InstanceRaw},
    resources::TextureId,
    texture::Texture,
};
use cgmath::*;
use wgpu::Extent3d;

#[readonly::make]
#[derive(Clone, Debug, PartialEq)]
pub struct Sprite {
    pub texture_id: TextureId,
    #[readonly]
    pub rotation: f32,
    #[readonly]
    pub position: Point2<f32>,
    #[readonly]
    pub scale: Point2<f32>,
    #[readonly]
    pub anchor: Point2<f32>,

    texture_size: Extent3d,
    instance: Instance,
    instance_raw: InstanceRaw,
}

impl Sprite {
    pub fn new(texture: &Texture) -> Self {
        let rotation = 0.0;
        let position = point2(0.0, 0.0);
        let scale = point2(1.0, 1.0);
        let anchor = point2(0.0, 0.0);

        let (instance, instance_raw) =
            update_instance(&anchor, &position, &scale, rotation, &texture.size);

        Sprite {
            scale,
            anchor,
            texture_id: texture.id,
            texture_size: texture.size,
            position,
            rotation,
            instance,
            instance_raw,
        }
    }

    pub(crate) fn get_raw_instance(&self) -> InstanceRaw {
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
            &self.texture_size,
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
            &self.texture_size,
        );
    }

    pub fn set_rotation(&mut self, rotation: f32) {
        self.rotation = rotation;

        (self.instance, self.instance_raw) = update_instance(
            &self.anchor,
            &self.position,
            &self.scale,
            self.rotation,
            &self.texture_size,
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
            &self.texture_size,
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
