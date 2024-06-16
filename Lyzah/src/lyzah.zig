const std = @import("std");

const window = @import("window/window.zig");
const window_utils = @import("window/utils.zig");

const renderer = @import("renderer/renderer.zig");

const Event = @import("events/event.zig").Event;
const EventDispatcher = @import("events/EventDispatcher.zig");

pub const Application = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}),
    allocator: std.mem.Allocator,

    window: window.Window,
    renderer: renderer.Renderer,

    pub fn init() !Application {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        EventDispatcher.init(allocator);

        var w = try window.Window.init(.{
            .name = "Lyzah",
            .width = 1280,
            .height = 720,
        });

        w.initWindowEvents();

        var app = Application{
            .gpa = gpa,
            .allocator = allocator,
            .window = w,
            .renderer = try renderer.Renderer.init(.{
                .name = "Lyzah",
                .allocator = allocator,
                .required_extensions = window_utils.getRequiredInstanceExtensions(),
            }, w.glfw_window),
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
            Event.window_resize => |resize_event| {
                _ = resize_event; // autofix
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
};
