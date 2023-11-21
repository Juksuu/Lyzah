const std = @import("std");

const glfw = @import("glfw");
const vk = @import("vulkan");

const window = @import("window");

pub const Application = struct {
    window: window.Window,

    pub fn init() !Application {
        var appInfo = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Hello Triangle",
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_0,
        };

        var createInfo = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
        };

        var instance: vk.VkInstance = null;
        if (vk.vkCreateInstance(&createInfo, null, &instance) != vk.VK_SUCCESS) {
            std.log.err("Could not create vulkan instance", .{});
            return error.VulkanInstanceError;
        }

        return Application{
            .window = try window.Window.init(.{
                .width = 1280,
                .height = 720,
                .name = "Lyzah",
            }),
        };
    }

    pub fn destroy(self: *Application) void {
        self.window.destroy();
    }

    pub fn run(self: *Application) void {
        while (self.window.shouldClose()) {
            self.window.pollEvents();
        }
    }
};
