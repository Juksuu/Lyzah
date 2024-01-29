const std = @import("std");
const vk = @import("vulkan");

const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

pub const RendererSpec = struct {
    name: [*c]const u8,
    required_extensions: [][*:0]const u8,
};

pub const Renderer = struct {
    instance: vk.VkInstance,
    debugMessenger: vk.VkDebugUtilsMessengerEXT,
    physicalDevice: vk.VkPhysicalDevice,

    pub fn init(spec: RendererSpec) !Renderer {
        if (enableValidationLayers and !(try utils.checkValidationLayerSupport(@constCast(&validationLayers)))) {
            return error.VulkanValidationLayersRequestedButNotAvailable;
        }

        const appInfo = vk.VkApplicationInfo{
            .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = spec.name,
            .applicationVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.VK_API_VERSION_1_3,
        };

        const instance = try createInstance(appInfo, &spec);
        const debugMessenger = try setupDebugCallback(instance);
        const physicalDevice = try pickPhysicalDevice(instance);

        return .{
            .instance = instance,
            .debugMessenger = debugMessenger,
            .physicalDevice = physicalDevice,
        };
    }

    pub fn destroy(self: *Renderer) void {
        if (enableValidationLayers) {
            self.destroyDebugMessenger();
        }
        vk.vkDestroyInstance(self.instance, null);
    }

    fn createInstance(appInfo: vk.VkApplicationInfo, spec: *const RendererSpec) !vk.VkInstance {
        const extensions = try addDebugExtension(spec);

        var createInfo = vk.VkInstanceCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = @intCast(extensions.len),
            .ppEnabledExtensionNames = @ptrCast(extensions),
        };

        if (enableValidationLayers) {
            createInfo.enabledLayerCount = validationLayers.len;
            createInfo.ppEnabledLayerNames = @ptrCast(&validationLayers);

            var debugCreateInfo = createDebugMessengerCreateInfo();
            createInfo.pNext = &debugCreateInfo;
        } else {
            createInfo.enabledLayerCount = 0;
        }

        var instance: vk.VkInstance = null;
        try utils.checkSuccess(vk.vkCreateInstance(&createInfo, null, &instance));

        return instance;
    }

    fn addDebugExtension(spec: *const RendererSpec) ![][*:0]const u8 {
        const allocator = std.heap.c_allocator;
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer extensions.deinit();

        try extensions.appendSlice(spec.required_extensions[0..spec.required_extensions.len]);

        if (enableValidationLayers) {
            try extensions.append(vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        }

        return try extensions.toOwnedSlice();
    }

    fn createDebugMessengerCreateInfo() vk.VkDebugUtilsMessengerCreateInfoEXT {
        const createInfo = vk.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = utils.debugCallback,
            .pUserData = null,
        };
        return createInfo;
    }

    fn setupDebugCallback(instance: vk.VkInstance) !vk.VkDebugUtilsMessengerEXT {
        if (!enableValidationLayers) return;

        var createInfo = createDebugMessengerCreateInfo();

        var debugMessenger: vk.VkDebugUtilsMessengerEXT = null;
        try utils.checkSuccess(try createDebugMessenger(instance, &createInfo, &debugMessenger));
        return debugMessenger;
    }

    fn createDebugMessenger(
        instance: vk.VkInstance,
        pCreateInfo: *const vk.VkDebugUtilsMessengerCreateInfoEXT,
        pDebugMessenger: *vk.VkDebugUtilsMessengerEXT,
    ) !vk.VkResult {
        const funcOpt = @as(vk.PFN_vkCreateDebugUtilsMessengerEXT, @ptrCast(vk.vkGetInstanceProcAddr(
            instance,
            "vkCreateDebugUtilsMessengerEXT",
        )));

        if (funcOpt) |func| {
            return func(instance, pCreateInfo, null, pDebugMessenger);
        }

        return error.VulkanDebugExtensionNotPresent;
    }

    fn destroyDebugMessenger(
        self: *Renderer,
    ) void {
        const func = @as(vk.PFN_vkDestroyDebugUtilsMessengerEXT, @ptrCast(vk.vkGetInstanceProcAddr(
            self.instance,
            "vkDestroyDebugUtilsMessengerEXT",
        ))) orelse unreachable;
        func(self.instance, self.debugMessenger, null);
    }

    fn pickPhysicalDevice(instance: vk.VkInstance) !vk.VkPhysicalDevice {
        var deviceCount: u32 = 0;
        try utils.checkSuccess(vk.vkEnumeratePhysicalDevices(instance, &deviceCount, null));

        if (deviceCount == 0) {
            return error.NoGPUWithVulkanSupport;
        }

        var allocator = std.heap.c_allocator;
        const devices = try allocator.alloc(vk.VkPhysicalDevice, deviceCount);
        defer allocator.free(devices);
        try utils.checkSuccess(vk.vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr));

        return for (devices) |device| {
            if (isDeviceSuitable(device)) {
                break device;
            }
        } else return error.NoSuitableGPU;
    }

    fn isDeviceSuitable(device: vk.VkPhysicalDevice) bool {
        _ = device;
        return true;
    }
};
