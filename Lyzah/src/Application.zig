const std = @import("std");

const Allocator = std.mem.Allocator;

const Window = @import("window/window.zig");
const window_utils = @import("window/utils.zig");

const Renderer = @import("renderer/renderer.zig");

const Event = @import("events/event.zig").Event;
const EventDispatcher = @import("events/EventDispatcher.zig");

const Application = @This();

gpa: std.heap.GeneralPurposeAllocator(.{}),
allocator: Allocator,

window: Window,
renderer: Renderer,

pub fn init() !Application {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    EventDispatcher.init(allocator);

    var window = try Window.init(.{
        .name = "Lyzah",
        .width = 1280,
        .height = 720,
    });

    window.initWindowEvents();

    var app = Application{
        .gpa = gpa,
        .allocator = allocator,
        .window = window,
        .renderer = try Renderer.init(.{
            .name = "Lyzah",
            .allocator = allocator,
            .required_extensions = window_utils.getRequiredInstanceExtensions(),
        }, window.glfw_window),
    };

    try EventDispatcher.addEventListener(.{
        .ptr = &app,
        .func = &onEvent,
    });

    return app;
}

fn onEvent(ptr: *anyopaque, event: Event) void {
    var app: *Application = @ptrCast(@alignCast(ptr));

    switch (event) {
        Event.window_resize => |_| {
            app.renderer.frame_buffer_resized = true;
        },
    }
}

pub fn destroy(self: *Application) void {
    EventDispatcher.destroy();

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
