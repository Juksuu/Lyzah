use crate::texture::Texture;
use image::{DynamicImage, ImageBuffer};
use legion::systems::Resource;
use std::{collections::HashMap, path::PathBuf};

pub type ResourceId = u32;

pub struct Resources {
    resources: HashMap<u32, Box<dyn Resource>>,
    resource_ids: HashMap<String, ResourceId>,
    next_resource_id: ResourceId,
    pub default_texture: Texture,
}

impl Resources {
    pub fn new() -> Self {
        let white_img = DynamicImage::ImageLuma8(ImageBuffer::from_fn(100, 100, |_x, _y| {
            image::Luma([255_u8])
        }));
        let white_box = Texture::from_image("white", white_img, 0);

        Resources {
            resources: HashMap::new(),
            resource_ids: HashMap::new(),
            default_texture: white_box,
            next_resource_id: 1,
        }
    }

    pub fn load_images(&mut self, images: Vec<PathBuf>) {
        for image in images {
            let name = image.file_name().unwrap().to_str().unwrap().to_string();
            let id = self.get_next_valid_id(name);

            let texture = Texture::new(image, id);

            self.resources.insert(id, Box::new(texture));
        }
    }

    pub fn get_next_valid_id(&mut self, name: String) -> ResourceId {
        let id = self.next_resource_id;

        self.resource_ids.insert(name, id);
        self.next_resource_id += 1;
        id
    }

    pub fn get<T: 'static>(&mut self, name: String) -> Option<&T> {
        let id = match self.resource_ids.get(&name) {
            Some(id) => id,
            None => return None,
        };

        match self.resources.get(&id) {
            Some(v) => v.downcast_ref::<T>(),
            None => None,
        }
    }

    pub fn get_by_id<T: 'static>(&self, id: ResourceId) -> Option<&T> {
        match self.resources.get(&id) {
            Some(v) => v.downcast_ref::<T>(),
            None => None,
        }
    }
}
