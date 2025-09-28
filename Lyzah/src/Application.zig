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

    var window = try Window.init(
        allocator,
        .{
            .name = "Lyzah",
            .width = 1280,
            .height = 720,
        },
    );

    window.initWindowEvents();

    return Application{
        .gpa = gpa,
        .allocator = allocator,
        .window = window,
        .renderer = try Renderer.init(
            allocator,
            .{
                .name = "Lyzah",
                .required_extensions = window_utils.getRequiredInstanceExtensions(),
            },
            window.glfw_window,
        ),
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

        for (self.window.events.items) |event| {
            self.onWindowEvent(event);
        }

        self.window.events.clearAndFree(std.heap.c_allocator);

        try self.renderer.drawFrame(self.window.glfw_window);
    }

    try self.renderer.waitForDevice();
}

pub fn onWindowEvent(self: *Application, event: Window.WindowEvent) void {
    switch (event) {
        .resize_event => self.renderer.frame_buffer_resized = true,
    }
}
