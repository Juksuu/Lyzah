use image::{DynamicImage, ImageBuffer};

use crate::texture::Texture;
use std::{collections::HashMap, path::PathBuf};

pub struct Resources {
    resources: HashMap<String, Texture>,
    default_texture: Texture,
}

impl Resources {
    pub fn new() -> Self {
        let white_img = DynamicImage::ImageLuma8(ImageBuffer::from_fn(100, 100, |_x, _y| {
            image::Luma([255_u8])
        }));
        let white_box = Texture::from_image("white", white_img);

        Resources {
            resources: HashMap::new(),
            default_texture: white_box,
        }
    }

    pub fn load_images(&mut self, images: Vec<PathBuf>) {
        for image in images {
            let name = image.file_name().unwrap().to_str().unwrap().to_string();
            let texture = Texture::new(image);

            self.resources.insert(name, texture);
        }
    }

    pub fn get(&self, name: &String) -> &Texture {
        &self.resources.get(name).unwrap_or(&self.default_texture)
    }
}
