use crate::texture::Texture;
use image::{DynamicImage, ImageBuffer};
use std::{collections::HashMap, fs, path::Path};

pub type ResourceId = u32;

enum Resource {
    Texture(Texture),
}

pub struct ResourceData<'a> {
    pub name: &'a str,
    pub path: &'a str,
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

    pub fn load_images(&mut self, resource_data: Vec<ResourceData>) {
        for resource in resource_data {
            let id = self.get_next_valid_id(resource.name);
            let ext = Path::new(resource.path).extension().unwrap();

            match fs::read(resource.path) {
                Ok(bytes) => {
                    self.resources.insert(
                        id,
                        Resource::Texture(Texture::new(
                            id,
                            resource.name,
                            &bytes,
                            image::ImageFormat::from_extension(ext),
                        )),
                    );
                }
                Err(err) => eprintln!("Error loading image {}. {}", resource.name, err),
            }
        }
    }

    pub fn get_next_valid_id(&mut self, name: &str) -> ResourceId {
        let id = self.next_resource_id;

        self.resource_ids.insert(name.to_string(), id);
        self.next_resource_id += 1;
        id
    }

    pub fn get_texture_id(&self, name: &str) -> ResourceId {
        match self.resource_ids.get(name) {
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
