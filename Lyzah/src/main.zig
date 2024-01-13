const std = @import("std");

const window = @import("window");
const renderer = @import("renderer");

pub const Application = struct {
    window: window.Window,
    renderer: renderer.Renderer,

    pub fn init() !Application {
        return Application{
            .window = try window.Window.init(.{
                .width = 1280,
                .height = 720,
                .name = "Lyzah",
            }),
            .renderer = try renderer.Renderer.init(.{
                .name = "Lyzah",
                .required_extensions = window.utils.getRequiredInstanceExtensions(),
            }),
        };
    }

    pub fn destroy(self: *Application) void {
        self.renderer.destroy();
        self.window.destroy();
    }

    pub fn run(self: *Application) void {
        while (self.window.shouldClose()) {
            self.window.pollEvents();
        }
    }
};
