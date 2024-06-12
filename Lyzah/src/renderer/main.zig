const std = @import("std");
const c = @import("../c.zig");

const utils = @import("utils.zig");

const maxInt = std.math.maxInt;
const Allocator = std.mem.Allocator;

const enableValidationLayers = std.debug.runtime_safety;
const validationLayers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

const deviceExtensions = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
const dynamicStates = [_]c_int{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };

const QueueFamilyIndices = struct {
    graphicsFamily: ?u32,
    presentFamily: ?u32,

    fn init() QueueFamilyIndices {
        return QueueFamilyIndices{
            .graphicsFamily = null,
            .presentFamily = null,
        };
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphicsFamily != null and self.presentFamily != null;
    }
};

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: std.ArrayList(c.VkSurfaceFormatKHR),
    presentModes: std.ArrayList(c.VkPresentModeKHR),

    fn init(allocator: Allocator) SwapChainSupportDetails {
        return SwapChainSupportDetails{
            .capabilities = undefined,
            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
            .presentModes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
        };
    }

    fn deinit(self: *SwapChainSupportDetails) void {
        self.formats.deinit();
        self.presentModes.deinit();
    }
};

const LogicalDeviceData = struct {
    device: c.VkDevice,
    graphicsQueue: c.VkQueue,
    presentQueue: c.VkQueue,
};

const SwapChainData = struct {
    swapChain: c.VkSwapchainKHR,
    images: std.ArrayList(c.VkImage),
    imageFormat: c.VkFormat,
    extent: c.VkExtent2D,
    imageViews: std.ArrayList(c.VkImageView),
};

const GraphicsPipelineData = struct {
    renderPass: c.VkRenderPass,
    layout: c.VkPipelineLayout,
    pipeline: c.VkPipeline,
};

pub const RendererSpec = struct {
    name: [*c]const u8,
    allocator: Allocator,
    required_extensions: [][*:0]const u8,
};

pub const Renderer = struct {
    allocator: Allocator,
    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,
    physicalDevice: c.VkPhysicalDevice,
    device: c.VkDevice,
    graphicsQueue: c.VkQueue,
    presentQueue: c.VkQueue,
    surface: c.VkSurfaceKHR,
    swapChainData: SwapChainData,
    graphicsPipelineData: GraphicsPipelineData,
    frameBuffers: std.ArrayList(c.VkFramebuffer),
    commandPool: c.VkCommandPool,
    commandBuffer: c.VkCommandBuffer,

    pub fn init(spec: RendererSpec, glfwWindow: *c.GLFWwindow) !Renderer {
        if (enableValidationLayers and !(try utils.checkValidationLayerSupport(spec.allocator, @constCast(&validationLayers)))) {
            return error.VulkanValidationLayersRequestedButNotAvailable;
        }

        const appInfo = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = spec.name,
            .applicationVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .pEngineName = spec.name,
            .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
            .apiVersion = c.VK_API_VERSION_1_3,
        };

        const instance = try createInstance(spec.allocator, spec.required_extensions, appInfo);
        const debugMessenger = try setupDebugCallback(instance);
        const surface = try createSurface(instance, glfwWindow);
        const physicalDevice = try pickPhysicalDevice(spec.allocator, instance, surface);
        const deviceData = try createLogicalDevice(spec.allocator, physicalDevice, surface);
        const swapChainData = try createSwapChain(spec.allocator, physicalDevice, surface, deviceData.device, glfwWindow);

        const renderPass = try createRenderPass(deviceData.device, swapChainData.imageFormat);
        const graphicsPipelineData = try createGraphicsPipeline(spec.allocator, deviceData.device, renderPass);

        const frameBuffers = try createFrameBuffers(spec.allocator, deviceData.device, renderPass, swapChainData);

        const commandPool = try createCommandPool(spec.allocator, physicalDevice, deviceData.device, surface);
        const commandBuffer = try createCommandBuffer(deviceData.device, commandPool);

        return Renderer{
            .allocator = spec.allocator,
            .instance = instance,
            .debugMessenger = debugMessenger,
            .physicalDevice = physicalDevice,
            .device = deviceData.device,
            .graphicsQueue = deviceData.graphicsQueue,
            .presentQueue = deviceData.presentQueue,
            .surface = surface,
            .swapChainData = swapChainData,
            .graphicsPipelineData = graphicsPipelineData,
            .frameBuffers = frameBuffers,
            .commandPool = commandPool,
            .commandBuffer = commandBuffer,
        };
    }

    pub fn destroy(self: *Renderer) void {
        if (enableValidationLayers) {
            self.destroyDebugMessenger();
        }

        for (self.frameBuffers.items) |frameBuffer| {
            c.vkDestroyFramebuffer(self.device, frameBuffer, null);
        }

        c.vkDestroyPipeline(self.device, self.graphicsPipelineData.pipeline, null);
        c.vkDestroyPipelineLayout(self.device, self.graphicsPipelineData.layout, null);
        c.vkDestroyRenderPass(self.device, self.graphicsPipelineData.renderPass, null);

        for (self.swapChainData.imageViews.items) |imageView| {
            c.vkDestroyImageView(self.device, imageView, null);
        }

        c.vkDestroySwapchainKHR(self.device, self.swapChainData.swapChain, null);
        c.vkDestroyDevice(self.device, null);
        c.vkDestroySurfaceKHR(self.instance, self.surface, null);
        c.vkDestroyInstance(self.instance, null);

        self.swapChainData.images.deinit();
        self.swapChainData.imageViews.deinit();
    }

    fn createInstance(allocator: Allocator, required_extensions: [][*:0]const u8, appInfo: c.VkApplicationInfo) !c.VkInstance {
        const extensions = try addDebugExtension(allocator, required_extensions);

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

    fn addDebugExtension(allocator: Allocator, required_extensions: [][*:0]const u8) ![][*:0]const u8 {
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer extensions.deinit();

        try extensions.appendSlice(required_extensions[0..required_extensions.len]);

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

    fn pickPhysicalDevice(allocator: Allocator, instance: c.VkInstance, surface: c.VkSurfaceKHR) !c.VkPhysicalDevice {
        var deviceCount: u32 = 0;
        try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, null));

        if (deviceCount == 0) {
            return error.NoGPUWithVulkanSupport;
        }

        const devices = try allocator.alloc(c.VkPhysicalDevice, deviceCount);
        defer allocator.free(devices);
        try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &deviceCount, devices.ptr));

        return for (devices) |device| {
            if (try isDeviceSuitable(allocator, device, surface)) {
                break device;
            }
        } else return error.NoSuitableGPU;
    }

    fn isDeviceSuitable(allocator: Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !bool {
        const indices = try findQueueFamilies(allocator, device, surface);
        const extensionsSupported = try utils.checkDeviceExtensionSupport(allocator, device, @constCast(&deviceExtensions));

        var swapChainAdequate = false;
        if (extensionsSupported) {
            var swapChainSupport = try querySwapChainSupport(allocator, device, surface);
            defer swapChainSupport.deinit();
            swapChainAdequate = swapChainSupport.formats.items.len > 0 and swapChainSupport.presentModes.items.len > 0;
        }

        return indices.isComplete() and swapChainAdequate;
    }

    fn findQueueFamilies(allocator: Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !QueueFamilyIndices {
        var indices = QueueFamilyIndices.init();

        var queueFamilyCount: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

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

    fn createLogicalDevice(allocator: Allocator, physicalDevice: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !LogicalDeviceData {
        const indices = try findQueueFamilies(allocator, physicalDevice, surface);

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
            .enabledExtensionCount = @intCast(deviceExtensions.len),
            .ppEnabledExtensionNames = &deviceExtensions,
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

    fn querySwapChainSupport(allocator: Allocator, device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapChainSupportDetails {
        var details = SwapChainSupportDetails.init(allocator);
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities));

        var formatCount: u32 = 0;
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, null));

        if (formatCount != 0) {
            try details.formats.resize(formatCount);
            try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &formatCount, details.formats.items.ptr));
        }

        var presentModeCount: u32 = 0;
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, null));

        if (presentModeCount != 0) {
            try details.presentModes.resize(presentModeCount);
            try utils.checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &presentModeCount, details.presentModes.items.ptr));
        }

        return details;
    }

    fn chooseSwapSurfaceFormat(availableFormats: std.ArrayList(c.VkSurfaceFormatKHR)) c.VkSurfaceFormatKHR {
        for (availableFormats.items) |format| {
            if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                return format;
            }
        }

        return availableFormats.items[0];
    }

    fn chooseSwapPresentMode(availablePresentModes: std.ArrayList(c.VkPresentModeKHR)) c.VkPresentModeKHR {
        for (availablePresentModes.items) |presentMode| {
            if (presentMode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                return presentMode;
            }
        }

        return c.VK_PRESENT_MODE_FIFO_KHR;
    }

    fn chooseSwapExtent(capabilities: c.VkSurfaceCapabilitiesKHR, window: *c.GLFWwindow) c.VkExtent2D {
        if (capabilities.currentExtent.width != maxInt(u32)) {
            return capabilities.currentExtent;
        } else {
            var width: c_int = undefined;
            var height: c_int = undefined;
            c.glfwGetFramebufferSize(window, &width, &height);

            var actualExtent = c.VkExtent2D{
                .width = @intCast(width),
                .height = @intCast(height),
            };

            actualExtent.width = std.math.clamp(actualExtent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
            actualExtent.height = std.math.clamp(actualExtent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
            return actualExtent;
        }
    }

    fn createSwapChain(allocator: Allocator, physicalDevice: c.VkPhysicalDevice, surface: c.VkSurfaceKHR, device: c.VkDevice, window: *c.GLFWwindow) !SwapChainData {
        var swapChainSupportDetails = try querySwapChainSupport(allocator, physicalDevice, surface);
        defer swapChainSupportDetails.deinit();

        const surfaceFormat = chooseSwapSurfaceFormat(swapChainSupportDetails.formats);
        const presentMode = chooseSwapPresentMode(swapChainSupportDetails.presentModes);
        const extent = chooseSwapExtent(swapChainSupportDetails.capabilities, window);

        var imageCount = swapChainSupportDetails.capabilities.minImageCount + 1;
        const maxImageCount = swapChainSupportDetails.capabilities.maxImageCount;

        if (maxImageCount > 0 and imageCount > maxImageCount) {
            imageCount = maxImageCount;
        }

        var createInfo: c.VkSwapchainCreateInfoKHR = .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = imageCount,
            .imageFormat = surfaceFormat.format,
            .imageColorSpace = surfaceFormat.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .preTransform = swapChainSupportDetails.capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = presentMode,
            .clipped = c.VK_TRUE,
            .oldSwapchain = null,
        };

        const indices = try findQueueFamilies(allocator, physicalDevice, surface);
        const queueFamilyIndices = [_]u32{ indices.graphicsFamily.?, indices.presentFamily.? };

        if (indices.graphicsFamily != indices.presentFamily) {
            createInfo.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
            createInfo.queueFamilyIndexCount = 2;
            createInfo.pQueueFamilyIndices = &queueFamilyIndices;
        } else {
            createInfo.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
            createInfo.queueFamilyIndexCount = 0;
            createInfo.pQueueFamilyIndices = null;
        }

        var swapChain: c.VkSwapchainKHR = undefined;
        try utils.checkSuccess(c.vkCreateSwapchainKHR(device, &createInfo, null, &swapChain));

        var swapChainImages = std.ArrayList(c.VkImage).init(allocator);
        try utils.checkSuccess(c.vkGetSwapchainImagesKHR(device, swapChain, &imageCount, null));
        try swapChainImages.resize(imageCount);
        try utils.checkSuccess(c.vkGetSwapchainImagesKHR(device, swapChain, &imageCount, swapChainImages.items.ptr));

        var swapChainImageViews = std.ArrayList(c.VkImageView).init(allocator);
        try swapChainImageViews.resize(swapChainImages.items.len);

        for (0..swapChainImages.items.len) |i| {
            const components: c.VkComponentMapping = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            };

            const subresourceRange: c.VkImageSubresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            };

            var imageViewCreateInfo: c.VkImageViewCreateInfo = .{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = swapChainImages.items[i],
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .format = surfaceFormat.format,
                .components = components,
                .subresourceRange = subresourceRange,
            };

            try utils.checkSuccess(c.vkCreateImageView(device, &imageViewCreateInfo, null, &swapChainImageViews.items[i]));
        }

        return SwapChainData{
            .swapChain = swapChain,
            .imageFormat = surfaceFormat.format,
            .extent = extent,
            .images = swapChainImages,
            .imageViews = swapChainImageViews,
        };
    }

    fn createRenderPass(device: c.VkDevice, swapchainImageFormat: c.VkFormat) !c.VkRenderPass {
        const colorAttachment: c.VkAttachmentDescription = .{
            .format = swapchainImageFormat,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        };

        const colorAttachmentRef: c.VkAttachmentReference = .{
            .attachment = 0,
            .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        const subpass: c.VkSubpassDescription = .{
            .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = &colorAttachmentRef,
        };

        const renderPassInfo: c.VkRenderPassCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &colorAttachment,
            .subpassCount = 1,
            .pSubpasses = &subpass,
        };

        var renderPass: c.VkRenderPass = undefined;
        try utils.checkSuccess(c.vkCreateRenderPass(device, &renderPassInfo, null, &renderPass));

        return renderPass;
    }

    fn createGraphicsPipeline(allocator: Allocator, device: c.VkDevice, renderPass: c.VkRenderPass) !GraphicsPipelineData {
        const vert = try utils.readFileToBuffer(allocator, "shaders/vert.spv");
        const frag = try utils.readFileToBuffer(allocator, "shaders/frag.spv");

        const vertModule = try utils.createShaderModule(vert, device);
        const fragModule = try utils.createShaderModule(frag, device);

        const vertShaderStageInfo: c.VkPipelineShaderStageCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vertModule,
            .pName = "main",
        };

        const fragShaderStageInfo: c.VkPipelineShaderStageCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = fragModule,
            .pName = "main",
        };

        const shaderStages = [_]c.VkPipelineShaderStageCreateInfo{ vertShaderStageInfo, fragShaderStageInfo };

        const vertexInputInfo: c.VkPipelineVertexInputStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 0,
            .pVertexBindingDescriptions = null,
            .vertexAttributeDescriptionCount = 0,
            .pVertexAttributeDescriptions = null,
        };

        const inputAssembly: c.VkPipelineInputAssemblyStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = c.VK_FALSE,
        };

        const viewPortState: c.VkPipelineViewportStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .scissorCount = 1,
        };

        const rasterizer: c.VkPipelineRasterizationStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = c.VK_FALSE,
            .rasterizerDiscardEnable = c.VK_FALSE,
            .polygonMode = c.VK_POLYGON_MODE_FILL,
            .lineWidth = 1.0,
            .cullMode = c.VK_CULL_MODE_BACK_BIT,
            .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = c.VK_FALSE,
        };

        const multisampling: c.VkPipelineMultisampleStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = c.VK_FALSE,
            .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        };

        const colorBlendAttachment: c.VkPipelineColorBlendAttachmentState = .{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = c.VK_FALSE,
        };

        const colorBlending: c.VkPipelineColorBlendStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.VK_FALSE,
            .attachmentCount = 1,
            .pAttachments = &colorBlendAttachment,
        };

        const pipelineLayoutInfo: c.VkPipelineLayoutCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        };

        var pipelineLayout: c.VkPipelineLayout = undefined;
        try utils.checkSuccess(c.vkCreatePipelineLayout(device, &pipelineLayoutInfo, null, &pipelineLayout));

        const dynamicState: c.VkPipelineDynamicStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = @intCast(dynamicStates.len),
            .pDynamicStates = @ptrCast(@constCast(&dynamicStates)),
        };

        const pipelineInfo: c.VkGraphicsPipelineCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = 2,
            .pStages = &shaderStages,
            .pVertexInputState = &vertexInputInfo,
            .pInputAssemblyState = &inputAssembly,
            .pViewportState = &viewPortState,
            .pRasterizationState = &rasterizer,
            .pMultisampleState = &multisampling,
            .pColorBlendState = &colorBlending,
            .pDynamicState = &dynamicState,
            .layout = pipelineLayout,
            .renderPass = renderPass,
            .subpass = 0,
        };

        var graphicsPipeline: c.VkPipeline = undefined;
        try utils.checkSuccess(c.vkCreateGraphicsPipelines(device, null, 1, &pipelineInfo, null, &graphicsPipeline));

        c.vkDestroyShaderModule(device, vertModule, null);
        c.vkDestroyShaderModule(device, fragModule, null);

        return GraphicsPipelineData{
            .layout = pipelineLayout,
            .renderPass = renderPass,
            .pipeline = graphicsPipeline,
        };
    }

    fn createFrameBuffers(allocator: Allocator, device: c.VkDevice, renderPass: c.VkRenderPass, swapChainData: SwapChainData) !std.ArrayList(c.VkFramebuffer) {
        var swapChainFrameBuffers = std.ArrayList(c.VkFramebuffer).init(allocator);
        try swapChainFrameBuffers.resize(swapChainData.imageViews.items.len);

        for (swapChainData.imageViews.items, 0..) |imageView, i| {
            const attachments = [_]c.VkImageView{imageView};

            const frameBufferCreateInfo: c.VkFramebufferCreateInfo = .{
                .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = renderPass,
                .attachmentCount = 1,
                .pAttachments = &attachments,
                .width = swapChainData.extent.width,
                .height = swapChainData.extent.height,
                .layers = 1,
            };

            try utils.checkSuccess(c.vkCreateFramebuffer(device, &frameBufferCreateInfo, null, &swapChainFrameBuffers.items[i]));
        }

        return swapChainFrameBuffers;
    }

    fn createCommandPool(allocator: Allocator, physicalDevice: c.VkPhysicalDevice, device: c.VkDevice, surface: c.VkSurfaceKHR) !c.VkCommandPool {
        const queueFamilyIndices = try findQueueFamilies(allocator, physicalDevice, surface);

        const poolInfo: c.VkCommandPoolCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queueFamilyIndices.graphicsFamily.?,
        };

        var commandPool: c.VkCommandPool = undefined;
        try utils.checkSuccess(c.vkCreateCommandPool(device, &poolInfo, null, &commandPool));

        return commandPool;
    }

    fn createCommandBuffer(device: c.VkDevice, commandPool: c.VkCommandPool) !c.VkCommandBuffer {
        const allocInfo: c.VkCommandBufferAllocateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = commandPool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };

        var commandBuffer: c.VkCommandBuffer = undefined;
        try utils.checkSuccess(c.vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer));

        return commandBuffer;
    }

    pub fn recordCommandBuffer(self: *Renderer, imageIndex: u32) void {
        const beginInfo: c.VkCommandBufferBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        };

        try utils.checkSuccess(c.vkBeginCommandBuffer(self.commandBuffer, &beginInfo));

        const clearColor = [1]c.VkClearValue{c.VkClearValue{
            .color = c.VkClearColorValue{ .float32 = [_]f32{ 0, 0, 0, 1 } },
        }};
        const renderPassInfo: c.VkRenderPassBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.graphicsPipelineData.renderPass,
            .framebuffer = self.frameBuffers.items[imageIndex],
            .renderArea = .{
                .offset = c.VkOffset2D{ .x = 0, .y = 0 },
                .extent = self.swapChainData.extent,
            },
            .clearValueCount = 1,
            .pClearValues = &clearColor,
        };

        c.vkCmdBeginRenderPass(self.commandBuffer, &renderPassInfo, c.VK_SUBPASS_CONTENTS_INLINE);

        c.vkCmdBindPipeline(self.commandBuffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphicsPipelineData.pipeline);

        const viewPort: c.VkViewport = .{
            .x = 0,
            .y = 0,
            .width = self.swapChainData.extent.width,
            .height = self.swapChainData.extent.height,
            .minDepth = 0,
            .maxDepth = 1,
        };

        c.vkCmdSetViewport(self.commandBuffer, 0, 1, &viewPort);

        const scissor: c.VkRect2D = .{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = self.swapChainData.extent,
        };

        c.vkCmdSetScissor(self.commandBuffer, 0, 1, &scissor);

        c.vkCmdDraw(self.commandBuffer, 3, 1, 0, 0);

        c.vkCmdEndRenderPass(self.commandBuffer);

        try utils.checkSuccess(c.vkEndCommandBuffer(self.commandBuffer));
    }
};
