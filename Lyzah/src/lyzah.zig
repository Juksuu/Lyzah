const std = @import("std");

const window = @import("window/window.zig");
const window_utils = @import("window/utils.zig");

const renderer = @import("renderer/renderer.zig");

pub const Application = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    allocator: std.mem.Allocator,

    window: window.Window,
    renderer: renderer.Renderer,

    pub fn init() !Application {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        const w = try window.Window.init(.{
            .name = "Lyzah",
            .width = 1280,
            .height = 720,
        });
        return Application{
            .gpa = gpa,
            .allocator = allocator,
            .window = w,
            .renderer = try renderer.Renderer.init(.{
                .name = "Lyzah",
                .allocator = allocator,
                .required_extensions = window_utils.getRequiredInstanceExtensions(),
            }, w.glfw_window),
        };
    }

    pub fn destroy(self: *Application) void {
        self.renderer.destroy();
        self.window.destroy();

        const deinit_status = self.gpa.deinit();
        if (deinit_status == .leak) @panic("Leaked memory");
    }

    pub fn run(self: *Application) !void {
        while (!self.window.shouldClose()) {
            self.window.pollEvents();
            try self.renderer.drawFrame(self.window.glfw_window);
        }

        try self.renderer.waitForDevice();
    }
};
