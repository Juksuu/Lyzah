const std = @import("std");
const c = @import("../c.zig");

const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const ResizeEvent = struct {
    width: u32,
    height: u32,
};

pub const WindowEvent = union(enum) {
    resize_event: ResizeEvent,
};

pub const WindowSpec = struct {
    width: u16,
    height: u16,
    name: [*c]const u8,
};

const Window = @This();

glfw_window: *c.GLFWwindow,
spec: WindowSpec,
allocator: Allocator,
events: *std.ArrayList(WindowEvent),

pub fn init(allocator: Allocator, spec: WindowSpec) !Window {
    _ = c.glfwSetErrorCallback(utils.errorCallback);

    if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;

    if (c.glfwVulkanSupported() != c.GLFW_TRUE) {
        std.log.err("GLFW could not find libvulkan", .{});
        return error.NoVulkan;
    }

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

    const window = c.glfwCreateWindow(
        @intCast(spec.width),
        @intCast(spec.height),
        spec.name,
        null,
        null,
    ) orelse return error.WindowInitFailed;

    // Need to use c allocator when passing the events to glfw user pointer
    const events = try std.heap.c_allocator.create(std.ArrayList(WindowEvent));
    events.* = std.ArrayList(WindowEvent).init(std.heap.c_allocator);

    return Window{
        .spec = spec,
        .glfw_window = window,
        .allocator = allocator,
        .events = events,
    };
}

pub fn initWindowEvents(self: *Window) void {
    c.glfwSetWindowUserPointer(self.glfw_window, self.events);

    const Callbacks = struct {
        fn frameBufferResized(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
            const events: *std.ArrayList(WindowEvent) = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));

            events.append(WindowEvent{
                .resize_event = ResizeEvent{ .width = @intCast(width), .height = @intCast(height) },
            }) catch {
                @panic("Out of memory");
            };
        }
    };

    _ = c.glfwSetFramebufferSizeCallback(self.glfw_window, Callbacks.frameBufferResized);
}

pub fn destroy(self: *Window) void {
    c.glfwDestroyWindow(self.glfw_window);
    c.glfwTerminate();

    self.events.deinit();
    std.heap.c_allocator.destroy(self.events);
}

pub fn shouldClose(self: *Window) bool {
    return c.glfwWindowShouldClose(self.glfw_window) == c.GLFW_TRUE;
}

pub fn pollEvents(self: Window) void {
    _ = self;
    c.glfwPollEvents();
}
