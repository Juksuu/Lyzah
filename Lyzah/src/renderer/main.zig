const std = @import("std");
const c = @import("../c.zig");

const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

pub const RendererSpec = struct {
    name: [*c]const u8,
    required_extensions: [][*:0]const u8,
};

pub const Renderer = struct {
    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,
    physicalDevice: c.VkPhysicalDevice,
    device: c.VkDevice,
    graphicsQueue: c.VkQueue,
    presentQueue: c.VkQueue,
    surface: c.VkSurfaceKHR,

    pub fn init(spec: RendererSpec, glfwWindow: *c.GLFWwindow) !Renderer {
        if (enableValidationLayers and !(try utils.checkValidationLayerSupport(@constCast(&validationLayers)))) {
            return error.VulkanValidationLayersRequestedButNotAvailable;
        }

        const appInfo = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = spec.name,
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = spec.name,
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_3,
        };

        const instance = try createInstance(appInfo, &spec);
        const debugMessenger = try setupDebugCallback(instance);
        const surface = try createSurface(instance, glfwWindow);
        const physicalDevice = try pickPhysicalDevice(instance, surface);
        const deviceData = try createLogicalDevice(physicalDevice, surface);

        return .{
            .instance = instance,
            .debugMessenger = debugMessenger,
            .physicalDevice = physicalDevice,
            .device = deviceData.device,
            .graphicsQueue = deviceData.graphicsQueue,
            .presentQueue = deviceData.presentQueue,
            .surface = surface,
        };
    }

    pub fn destroy(self: *Renderer) void {
        if (enableValidationLayers) {
            self.destroyDebugMessenger();
        }
        c.vkDestroyDevice(self.device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);
    }

    fn createInstance(appInfo: c.VkApplicationInfo, spec: *const RendererSpec) !c.VkInstance {
        const extensions = try addDebugExtension(spec);

        var createInfo = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
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

        var instance: c.VkInstance = null;
        try utils.checkSuccess(c.vkCreateInstance(&createInfo, null, &instance));

        return instance;
    }

    fn addDebugExtension(spec: *const RendererSpec) ![][*:0]const u8 {
        const allocator = std.heap.c_allocator;
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer extensions.deinit();

        try extensions.appendSlice(spec.required_extensions[0..spec.required_extensions.len]);

        if (enableValidationLayers) {
            try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
        }

        return try extensions.toOwnedSlice();
    }

    fn createDebugMessengerCreateInfo() c.VkDebugUtilsMessengerCreateInfoEXT {
        const createInfo = c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = utils.debugCallback,
            .pUserData = null,
        };
        return createInfo;
    }

    fn setupDebugCallback(instance: c.VkInstance) !c.VkDebugUtilsMessengerEXT {
        if (!enableValidationLayers) return;

        var createInfo = createDebugMessengerCreateInfo();

        var debugMessenger: c.VkDebugUtilsMessengerEXT = null;
        try utils.checkSuccess(try createDebugMessenger(instance, &createInfo, &debugMessenger));
        return debugMessenger;
    }

    fn createDebugMessenger(
        instance: c.VkInstance,
        pCreateInfo: *const c.VkDebugUtilsMessengerCreateInfoEXT,
        pDebugMessenger: *c.VkDebugUtilsMessengerEXT,
    ) !c.VkResult {
        const funcOpt = @as(c.PFN_vkCreateDebugUtilsMessengerEXT, @ptrCast(c.vkGetInstanceProcAddr(
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
        const func = @as(c.PFN_vkDestroyDebugUtilsMessengerEXT, @ptrCast(c.vkGetInstanceProcAddr(
            self.instance,
            "vkDestroyDebugUtilsMessengerEXT",
        ))) orelse unreachable;
        func(self.instance, self.debugMessenger, null);
    }

    fn pickPhysicalDevice(instance: c.VkInstance, surface: c.VkSurfaceKHR) !c.VkPhysicalDevice {
        var deviceCount: u32 = 0;
        try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, null));

        if (deviceCount == 0) {
            return error.NoGPUWithVulkanSupport;
        }

        var allocator = std.heap.c_allocator;
        const devices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer allocator.free(devices);
        try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr));

        return for (devices) |device| {
            if (try isDeviceSuitable(device, surface)) {
                break device;
            }
        } else return error.NoSuitableGPU;
    }

    fn isDeviceSuitable(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !bool {
        const indices = try findQueueFamilies(device, surface);
        return indices.isComplete();
    }

    fn findQueueFamilies(device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = .{ .graphicsFamily = null, .presentFamily = null };

        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

        var allocator = std.heap.c_allocator;
        const queueFamilies = try allocator.alloc(c.VkQueueFamilyProperties, queueFamilyCount);
        defer allocator.free(queueFamilies);

        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.ptr);

        for (0.., queueFamilies) |i, family| {
            if ((family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                indices.graphicsFamily = @truncate(i);
            }

            var presentSupport: c.VkBool32 = c.VK_FALSE;
            try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceSupportKHR(device, @truncate(i), surface, &presentSupport));

            if (presentSupport == c.VK_TRUE) {
                indices.presentFamily = @truncate(i);
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }

    fn createLogicalDevice(physicalDevice: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !struct { device: c.VkDevice, graphicsQueue: c.VkQueue, presentQueue: c.VkQueue } {
        const indices = try findQueueFamilies(physicalDevice, surface);

        const allocator = std.heap.c_allocator;

        var queueCreateInfos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(allocator);
        queueCreateInfos.deinit();

        const allQueueFamilies = [_]u32{ indices.graphicsFamily.?, indices.presentFamily.? };
        const uniqueQueueFamilies = if (indices.graphicsFamily.? == indices.presentFamily.?)
            allQueueFamilies[0..1]
        else
            allQueueFamilies[0..2];

        const queuePriority: f32 = 1.0;
        for (uniqueQueueFamilies) |queueFamily| {
            const queueCreateInfo: c.VkDeviceQueueCreateInfo = .{
                .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                .queueFamilyIndex = queueFamily,
                .queueCount = 1,
                .pQueuePriorities = &queuePriority,
            };

            try queueCreateInfos.append(queueCreateInfo);
        }

        var deviceFeatures: c.VkPhysicalDeviceFeatures = .{};

        var deviceCreateInfo: c.VkDeviceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pQueueCreateInfos = queueCreateInfos.items.ptr,
            .queueCreateInfoCount = @truncate(queueCreateInfos.items.len),
            .pEnabledFeatures = &deviceFeatures,
            .enabledExtensionCount = 0,
        };

        if (enableValidationLayers) {
            deviceCreateInfo.enabledLayerCount = validationLayers.len;
            deviceCreateInfo.ppEnabledLayerNames = @ptrCast(&validationLayers);
        } else {
            deviceCreateInfo.enabledLayerCount = 0;
        }

        var device: c.VkDevice = null;
        try utils.checkSuccess(c.vkCreateDevice(physicalDevice, &deviceCreateInfo, null, &device));

        var graphicsQueue: c.VkQueue = null;
        c.vkGetDeviceQueue(device, indices.graphicsFamily.?, 0, &graphicsQueue);

        var presentQueue: c.VkQueue = null;
        c.vkGetDeviceQueue(device, indices.presentFamily.?, 0, &presentQueue);

        return .{ .device = device, .graphicsQueue = graphicsQueue, .presentQueue = presentQueue };
    }

    fn createSurface(instance: c.VkInstance, window: *c.GLFWwindow) !c.VkSurfaceKHR {
        var surface: c.VkSurfaceKHR = null;
        try utils.checkSuccess(c.glfwCreateWindowSurface(instance, window, null, &surface));
        return surface;
    }
};
