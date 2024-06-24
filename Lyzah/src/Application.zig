const std = @import("std");

const Allocator = std.mem.Allocator;

const Window = @import("window/window.zig");
const window_utils = @import("window/utils.zig");

const Renderer = @import("renderer/renderer.zig");

const Application = @This();

gpa: std.heap.GeneralPurposeAllocator(.{}),
allocator: Allocator,

window: Window,
renderer: Renderer,

pub fn init() !Application {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var window = try Window.init(.{
        .name = "Lyzah",
        .width = 1280,
        .height = 720,
    });

    window.initWindowEvents();

    return Application{
        .gpa = gpa,
        .allocator = allocator,
        .window = window,
        .renderer = try Renderer.init(.{
            .name = "Lyzah",
            .allocator = allocator,
            .required_extensions = window_utils.getRequiredInstanceExtensions(),
        }, window.glfw_window),
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
