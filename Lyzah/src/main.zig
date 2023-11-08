const std = @import("std");
const glfw = @import("c.zig").glfw;
const vulkan = @import("c.zig").vk;

pub const Application = struct {
    window: *glfw.GLFWwindow,

    pub fn init() !Application {
        if (glfw.glfwInit() != glfw.GLFW_TRUE) return error.GlfwInitFailed;

        if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
            std.log.err("GLFW could not find libvulkan", .{});
            return error.NoVulkan;
        }

        var appInfo = vulkan.VkApplicationInfo{};
        appInfo.sType = vulkan.VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = "Hello Triangle";
        appInfo.applicationVersion = vulkan.VK_MAKE_VERSION(1, 0, 0);
        appInfo.pEngineName = "No Engine";
        appInfo.engineVersion = vulkan.VK_MAKE_VERSION(1, 0, 0);
        appInfo.apiVersion = vulkan.VK_API_VERSION_1_0;

        var createInfo = vulkan.VkInstanceCreateInfo{};
        createInfo.sType = vulkan.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;

        var instance: vulkan.VkInstance = null;
        if (vulkan.vkCreateInstance(&createInfo, null, &instance) != vulkan.VK_SUCCESS) {
            std.log.err("Could not createInstance", .{});
            return error.VulkanInstanceError;
        }

        glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
        const window = glfw.glfwCreateWindow(
            @intCast(1280),
            @intCast(720),
            "Lyzah",
            null,
            null,
        ) orelse return error.WindowInitFailed;

        return Application{ .window = window };
    }

    pub fn destroy(self: *Application) void {
        glfw.glfwDestroyWindow(self.window);
        glfw.glfwTerminate();
    }

    pub fn run(self: *Application) void {
        while (glfw.glfwWindowShouldClose(self.window) == glfw.GLFW_FALSE) {
            glfw.glfwPollEvents();
        }
    }
};
