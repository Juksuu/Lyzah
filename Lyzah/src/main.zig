const std = @import("std");

const window = @import("./window/main.zig");
const renderer = @import("./renderer/main.zig");

pub const Application = struct {
    window: window.Window,
    renderer: renderer.Renderer,

    pub fn init() !Application {
        const w = try window.Window.init(.{
            .name = "Lyzah",
            .width = 1280,
            .height = 720,
        });
        return Application{
            .window = w,
            .renderer = try renderer.Renderer.init(.{
                .name = "Lyzah",
                .required_extensions = window.utils.getRequiredInstanceExtensions(),
            }, w.glfw_window),
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
