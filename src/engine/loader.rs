use crate::texture::Texture;
use image::{DynamicImage, ImageBuffer};
use std::{collections::HashMap, path::PathBuf};

pub type ResourceId = u32;

enum Resource {
    Texture(Texture),
}

pub struct Loader {
    resources: HashMap<ResourceId, Resource>,
    resource_ids: HashMap<String, ResourceId>,
    next_resource_id: ResourceId,
    pub default_texture: Texture,
}

impl Loader {
    pub fn new() -> Self {
        let white_img = DynamicImage::ImageLuma8(ImageBuffer::from_fn(100, 100, |_x, _y| {
            image::Luma([255_u8])
        }));
        let white_box = Texture::from_image("white", white_img, 0);

        Loader {
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

            self.resources
                .insert(id, Resource::Texture(Texture::new(image, id)));
        }
    }

    pub fn get_next_valid_id(&mut self, name: String) -> ResourceId {
        let id = self.next_resource_id;

        self.resource_ids.insert(name, id);
        self.next_resource_id += 1;
        id
    }

    pub fn get_texture_id(&self, name: String) -> ResourceId {
        match self.resource_ids.get(&name) {
            Some(id) => *id,
            None => 0,
        }
    }

    pub(crate) fn get_texture_by_id(&self, id: ResourceId) -> &Texture {
        match self.resources.get(&id) {
            Some(Resource::Texture(v)) => v,
            None => &self.default_texture,
        }
    }
}
