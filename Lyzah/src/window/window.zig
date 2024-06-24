const std = @import("std");
const c = @import("../c.zig");

const utils = @import("utils.zig");

pub const WindowSpec = struct {
    width: u16,
    height: u16,
    name: [*c]const u8,
};

const Window = @This();

glfw_window: *c.GLFWwindow,
spec: WindowSpec,

pub fn init(spec: WindowSpec) !Window {
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

    return Window{ .spec = spec, .glfw_window = window };
}

pub fn initWindowEvents(self: *Window) void {
    const Callbacks = struct {
        fn frameBufferResized(_: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
            _ = height; // autofix
            _ = width; // autofix
        }
    };

    _ = c.glfwSetFramebufferSizeCallback(self.glfw_window, Callbacks.frameBufferResized);
}

pub fn destroy(self: *Window) void {
    c.glfwDestroyWindow(self.glfw_window);
    c.glfwTerminate();
}

pub fn shouldClose(self: *Window) bool {
    return c.glfwWindowShouldClose(self.glfw_window) == c.GLFW_TRUE;
}

pub fn pollEvents(self: *Window) void {
    _ = self;
    c.glfwPollEvents();
}
