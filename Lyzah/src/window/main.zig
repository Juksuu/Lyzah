const std = @import("std");
const glfw = @import("glfw");

pub const utils = @import("utils.zig");

pub const WindowSpec = struct {
    width: u16,
    height: u16,
    name: [*c]const u8,
};

pub const Window = struct {
    glfw_window: *glfw.GLFWwindow,

    pub fn init(spec: WindowSpec) !Window {
        if (glfw.glfwInit() != glfw.GLFW_TRUE) return error.GlfwInitFailed;

        if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
            std.log.err("GLFW could not find libvulkan", .{});
            return error.NoVulkan;
        }

        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

        const window = glfw.glfwCreateWindow(
            @intCast(spec.width),
            @intCast(spec.height),
            spec.name,
            null,
            null,
        ) orelse return error.WindowInitFailed;

        return Window{ .glfw_window = window };
    }

    pub fn destroy(self: *Window) void {
        glfw.glfwDestroyWindow(self.glfw_window);
        glfw.glfwTerminate();
    }

    pub fn shouldClose(self: *Window) bool {
        return glfw.glfwWindowShouldClose(self.glfw_window) == glfw.GLFW_FALSE;
    }

    pub fn pollEvents(self: *Window) void {
        _ = self;
        glfw.glfwPollEvents();
    }
};
