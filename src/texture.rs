use crate::resources::TextureId;
use crate::vertex::Vertex;
use image::{DynamicImage, GenericImageView};
use std::fs;
use std::path::PathBuf;

pub struct Texture {
    pub name: String,
    pub id: TextureId,
    pub size: wgpu::Extent3d,
    pub image: image::DynamicImage,
    pub vertices: Vec<Vertex>,
    pub indices: Vec<u16>,
}

impl Texture {
    pub fn new(path: PathBuf, id: TextureId) -> Self {
        let name = path.file_name().unwrap().to_str().unwrap().to_string();
        let bytes = fs::read(path).unwrap();
        let image = image::load_from_memory(&bytes).unwrap();

        let dimensions = image.dimensions();

        let size = wgpu::Extent3d {
            width: dimensions.0,
            height: dimensions.1,
            depth_or_array_layers: 1,
        };

        let (vertices, indices) = calculate_buffers(dimensions.0 as f32, dimensions.1 as f32);

        Texture {
            id,
            name,
            size,
            image,
            vertices,
            indices,
        }
    }

    pub fn from_image(name: &str, image: DynamicImage, id: TextureId) -> Self {
        let dimensions = image.dimensions();

        let size = wgpu::Extent3d {
            width: dimensions.0,
            height: dimensions.1,
            depth_or_array_layers: 1,
        };

        let (vertices, indices) = calculate_buffers(dimensions.0 as f32, dimensions.1 as f32);

        Texture {
            id,
            name: name.to_string(),
            size,
            image,
            vertices,
            indices,
        }
    }
}

fn calculate_buffers(width: f32, height: f32) -> (Vec<Vertex>, Vec<u16>) {
    #[rustfmt::skip]
    let vertices: Vec<Vertex> = vec![
        Vertex { position: [0.0, -height, 0.0], tex_coords: [0.0, 1.0] },
        Vertex { position: [width, -height, 0.0], tex_coords: [1.0, 1.0] },
        Vertex { position: [width, 0.0, 0.0], tex_coords: [1.0, 0.0] },
        Vertex { position: [0.0, 0.0, 0.0], tex_coords: [0.0, 0.0] },
    ];

    #[rustfmt::skip]
    let indices: Vec<u16> = vec![
        0, 1, 2,
        0, 2, 3,
    ];

    (vertices, indices)
}
