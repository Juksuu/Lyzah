use crate::texture::Texture;
use image::{DynamicImage, ImageBuffer};
use std::{collections::HashMap, path::PathBuf};

pub type TextureId = u32;

pub struct Resources {
    resources: HashMap<u32, Texture>,
    resource_ids: HashMap<String, TextureId>,
    next_resource_id: TextureId,
    default_texture: Texture,
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
            let id = self.resolve_texture_id(name);

            let texture = Texture::new(image, id);

            self.resources.insert(id, texture);
        }
    }

    pub fn resolve_texture_id(&mut self, name: String) -> TextureId {
        if let Some(id) = self.resource_ids.get(&name) {
            return *id;
        }

        let id = self.next_resource_id;

        self.resource_ids.insert(name, id);
        self.next_resource_id += 1;
        id
    }

    pub fn get(&mut self, name: String) -> &Texture {
        let id = self.resolve_texture_id(name);
        &self.resources.get(&id).unwrap_or(&self.default_texture)
    }

    pub fn get_by_id(&self, id: TextureId) -> &Texture {
        &self.resources.get(&id).unwrap_or(&self.default_texture)
    }
}
