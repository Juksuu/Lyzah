const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

const Window = @import("window/window.zig");
const window_utils = @import("window/utils.zig");

const Renderer = @import("renderer/renderer.zig");

const Application = @This();

allocator: Allocator,
safe_allocator: std.heap.SafeAllocator,

io: std.Io,
threaded: std.Io.Threaded,

window: Window,
renderer: Renderer,

pub fn init() !Application {
    var safe_allocator: std.heap.SafeAllocator = .init(std.heap.page_allocator, .{});
    const allocator: Allocator =
        if (builtin.mode == .debug)
            safe_allocator.allocator()
        else
            std.heap.smp_allocator;

    var threaded: std.Io.Threaded = .init(allocator, .{});
    const io = threaded.io();

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
        .allocator = allocator,
        .safe_allocator = safe_allocator,

        .io = io,
        .threaded = threaded,

        .window = window,
        .renderer = try Renderer.init(
            io,
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

    self.threaded.deinit();

    if (builtin.mode == .debug) {
        const deinit_status = self.safe_allocator.deinit();
        if (deinit_status != 0) @panic("Leaked memory");
    }
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
