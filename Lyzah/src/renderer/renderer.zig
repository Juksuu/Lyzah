const std = @import("std");
const zmath = @import("zmath");
const zstbi = @import("zstbi");

const c = @import("../c.zig");

const utils = @import("utils.zig");

const time = std.time;
const maxInt = std.math.maxInt;
const Allocator = std.mem.Allocator;

const ENABLE_VALIDATION_LAYERS = std.debug.runtime_safety;
const VALIDATION_LAYERS = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

const DEVICE_EXTENSIONS = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};
const DYNAMIC_STATES = [_]c_int{ c.VK_DYNAMIC_STATE_VIEWPORT, c.VK_DYNAMIC_STATE_SCISSOR };

const MAX_FRAMES_IN_FLIGHT = 2;

const UniformBufferObject = extern struct {
    model: zmath.Mat align(16),
    view: zmath.Mat align(16),
    proj: zmath.Mat align(16),
};

const Vertex = struct {
    pos: @Vector(3, f32),
    color: @Vector(3, f32),
    tex_coord: @Vector(2, f32),

    pub fn getBindingDescription() c.VkVertexInputBindingDescription {
        const binding_description: c.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };
        return binding_description;
    }

    pub fn getAttributeDescriptions() [3]c.VkVertexInputAttributeDescription {
        const position_attribute: c.VkVertexInputAttributeDescription = .{
            .binding = 0,
            .location = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "pos"),
        };

        const color_attribute: c.VkVertexInputAttributeDescription = .{
            .binding = 0,
            .location = 1,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = @offsetOf(Vertex, "color"),
        };

        const tex_coord_attribute: c.VkVertexInputAttributeDescription = .{
            .binding = 0,
            .location = 2,
            .format = c.VK_FORMAT_R32G32_SFLOAT,
            .offset = @offsetOf(Vertex, "tex_coord"),
        };

        return [_]c.VkVertexInputAttributeDescription{ position_attribute, color_attribute, tex_coord_attribute };
    }
};

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,
    transfer_family: ?u32,

    fn init() QueueFamilyIndices {
        return QueueFamilyIndices{
            .graphics_family = null,
            .present_family = null,
            .transfer_family = null,
        };
    }

    fn isComplete(self: QueueFamilyIndices) bool {
        return self.graphics_family != null and self.present_family != null and self.transfer_family != null;
    }
};

const SwapchainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: std.ArrayList(c.VkSurfaceFormatKHR),
    present_modes: std.ArrayList(c.VkPresentModeKHR),

    fn init(allocator: Allocator) SwapchainSupportDetails {
        return SwapchainSupportDetails{
            .capabilities = undefined,
            .formats = std.ArrayList(c.VkSurfaceFormatKHR).init(allocator),
            .present_modes = std.ArrayList(c.VkPresentModeKHR).init(allocator),
        };
    }

    fn deinit(self: *SwapchainSupportDetails) void {
        self.formats.deinit();
        self.present_modes.deinit();
    }
};

const QueueData = struct {
    queue: c.VkQueue,
    index: u32,
};

const LogicalDeviceData = struct {
    device: c.VkDevice,
    graphics_queue: QueueData,
    present_queue: QueueData,
    transfer_queue: QueueData,
};

const SwapchainData = struct {
    swapchain: c.VkSwapchainKHR,
    images: []c.VkImage,
    image_format: c.VkFormat,
    extent: c.VkExtent2D,
    image_views: []c.VkImageView,
};

const GraphicsPipelineData = struct {
    render_pass: c.VkRenderPass,
    layout: c.VkPipelineLayout,
    pipeline: c.VkPipeline,
};

const SyncObjects = struct {
    image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore,
    render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]c.VkSemaphore,
    in_flight_fences: [MAX_FRAMES_IN_FLIGHT]c.VkFence,
};

const BufferData = struct {
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
};

const UniformBufferData = struct {
    buffers: [MAX_FRAMES_IN_FLIGHT]c.VkBuffer,
    buffers_memory: [MAX_FRAMES_IN_FLIGHT]c.VkDeviceMemory,
};

const TextureImageData = struct {
    image: c.VkImage,
    image_memory: c.VkDeviceMemory,
};

const DepthResources = struct {
    image: c.VkImage,
    image_memory: c.VkDeviceMemory,
    image_view: c.VkImageView,
};

const ModelData = struct {
    vertices: []Vertex,
    indices: []u32,
};

pub const RendererSpec = struct {
    name: [*c]const u8,
    required_extensions: [][*:0]const u8,
};

const Renderer = @This();

allocator: Allocator,
instance: c.VkInstance,
debug_messenger: c.VkDebugUtilsMessengerEXT,
physical_device: c.VkPhysicalDevice,
logical_device_data: LogicalDeviceData,
surface: c.VkSurfaceKHR,
swapchain_data: SwapchainData,
descriptor_set_layout: c.VkDescriptorSetLayout,
graphics_pipeline_data: GraphicsPipelineData,
frame_buffers: []c.VkFramebuffer,
command_pool: c.VkCommandPool,
command_buffers: []c.VkCommandBuffer,
transfer_command_pool: c.VkCommandPool,
sync_objects: SyncObjects,
vertices: []Vertex,
vertex_buffer: c.VkBuffer,
vertex_buffer_memory: c.VkDeviceMemory,
indices: []u32,
index_buffer: c.VkBuffer,
index_buffer_memory: c.VkDeviceMemory,
uniform_buffers: UniformBufferData,
descriptor_pool: c.VkDescriptorPool,
descriptor_sets: [MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSet,
image_data: TextureImageData,
image_view: c.VkImageView,
texture_sampler: c.VkSampler,
depth_resources: DepthResources,

current_frame: u32,
last_frame_time: time.Instant,
start_time: time.Instant,
frame_buffer_resized: bool,

pub fn init(allocator: Allocator, spec: RendererSpec, glfw_window: *c.GLFWwindow) !Renderer {
    if (ENABLE_VALIDATION_LAYERS and !(try utils.checkValidationLayerSupport(allocator, @constCast(&VALIDATION_LAYERS)))) {
        return error.VulkanValidationLayersRequestedButNotAvailable;
    }

    zstbi.init(std.heap.c_allocator);

    const app_info = c.VkApplicationInfo{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = spec.name,
        .applicationVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .pEngineName = spec.name,
        .engineVersion = c.VK_MAKE_VERSION(0, 1, 0),
        .apiVersion = c.VK_API_VERSION_1_3,
    };

    const instance = try createInstance(allocator, spec.required_extensions, app_info);
    const debug_messenger = try setupDebugCallback(instance);
    const surface = try createSurface(instance, glfw_window);
    const physical_device = try pickPhysicalDevice(std.heap.c_allocator, instance, surface);
    const logical_device_data = try createLogicalDevice(std.heap.c_allocator, physical_device, surface);

    const logical_device = logical_device_data.device;

    const swapchain_data = try createSwapChain(std.heap.c_allocator, physical_device, surface, logical_device, glfw_window);
    const render_pass = try createRenderPass(logical_device, physical_device, swapchain_data.image_format);
    const descriptor_set_layout = try createDescriptorSetLayout(logical_device);
    const graphics_pipeline_data = try createGraphicsPipeline(allocator, logical_device, render_pass, descriptor_set_layout);

    const command_pool = try createCommandPool(logical_device, logical_device_data.graphics_queue.index, c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
    const command_buffers = try createCommandBuffers(std.heap.c_allocator, logical_device, command_pool);

    const sync_objects = try createSyncObjects(logical_device);

    const transfer_command_pool = try createCommandPool(logical_device, logical_device_data.transfer_queue.index, c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT);

    const model_data = try loadObjModel(allocator, "assets/viking_room.obj");

    const vertex_buffer_data = try createVertexBuffer(logical_device, physical_device, model_data.vertices, transfer_command_pool, logical_device_data.transfer_queue.queue);

    const index_buffer_data = try createIndexBuffer(logical_device, physical_device, model_data.indices, transfer_command_pool, logical_device_data.transfer_queue.queue);

    const uniform_buffer_data = try createUniformBuffers(logical_device, physical_device);

    const depth_resources = try createDepthResources(logical_device, physical_device, swapchain_data.extent);

    const frame_buffers = try createFrameBuffers(std.heap.c_allocator, logical_device, render_pass, swapchain_data, depth_resources.image_view);

    const image_data = try createTextureImage("assets/viking_room.png", logical_device, physical_device, command_pool, logical_device_data.graphics_queue.queue);

    const image_view = try createImageView(logical_device, image_data.image, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_ASPECT_COLOR_BIT);

    const sampler = try createTextureSampler(logical_device, physical_device);

    const descriptor_pool = try createDescriptorPool(logical_device);
    const descriptor_sets = try createDescriptorSets(logical_device, descriptor_set_layout, descriptor_pool, uniform_buffer_data, image_view, sampler);

    return Renderer{
        .current_frame = 0,
        .last_frame_time = try time.Instant.now(),
        .start_time = try time.Instant.now(),
        .frame_buffer_resized = false,
        .allocator = allocator,
        .instance = instance,
        .debug_messenger = debug_messenger,
        .physical_device = physical_device,
        .logical_device_data = logical_device_data,
        .surface = surface,
        .swapchain_data = swapchain_data,
        .descriptor_set_layout = descriptor_set_layout,
        .graphics_pipeline_data = graphics_pipeline_data,
        .frame_buffers = frame_buffers,
        .command_pool = command_pool,
        .command_buffers = command_buffers,
        .transfer_command_pool = transfer_command_pool,
        .sync_objects = sync_objects,
        .vertices = model_data.vertices,
        .vertex_buffer = vertex_buffer_data.buffer,
        .vertex_buffer_memory = vertex_buffer_data.memory,
        .indices = model_data.indices,
        .index_buffer = index_buffer_data.buffer,
        .index_buffer_memory = index_buffer_data.memory,
        .uniform_buffers = uniform_buffer_data,
        .descriptor_pool = descriptor_pool,
        .descriptor_sets = descriptor_sets,
        .image_data = image_data,
        .image_view = image_view,
        .texture_sampler = sampler,
        .depth_resources = depth_resources,
    };
}

fn destroySwapchain(self: Renderer) void {
    c.vkDestroyImageView(self.logical_device_data.device, self.depth_resources.image_view, null);
    c.vkDestroyImage(self.logical_device_data.device, self.depth_resources.image, null);
    c.vkFreeMemory(self.logical_device_data.device, self.depth_resources.image_memory, null);

    for (self.frame_buffers) |frame_buffer| {
        c.vkDestroyFramebuffer(self.logical_device_data.device, frame_buffer, null);
    }

    for (self.swapchain_data.image_views) |image_view| {
        c.vkDestroyImageView(self.logical_device_data.device, image_view, null);
    }

    c.vkDestroySwapchainKHR(self.logical_device_data.device, self.swapchain_data.swapchain, null);
}

pub fn destroy(self: *Renderer) void {
    if (ENABLE_VALIDATION_LAYERS) {
        self.destroyDebugMessenger();
    }

    self.destroySwapchain();

    c.vkDestroySampler(self.logical_device_data.device, self.texture_sampler, null);
    c.vkDestroyImageView(self.logical_device_data.device, self.image_view, null);

    c.vkDestroyImage(self.logical_device_data.device, self.image_data.image, null);
    c.vkFreeMemory(self.logical_device_data.device, self.image_data.image_memory, null);

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroyBuffer(self.logical_device_data.device, self.uniform_buffers.buffers[i], null);
        c.vkFreeMemory(self.logical_device_data.device, self.uniform_buffers.buffers_memory[i], null);
    }

    c.vkDestroyDescriptorPool(self.logical_device_data.device, self.descriptor_pool, null);

    c.vkDestroyDescriptorSetLayout(self.logical_device_data.device, self.descriptor_set_layout, null);

    c.vkDestroyBuffer(self.logical_device_data.device, self.vertex_buffer, null);
    c.vkFreeMemory(self.logical_device_data.device, self.vertex_buffer_memory, null);

    c.vkDestroyBuffer(self.logical_device_data.device, self.index_buffer, null);
    c.vkFreeMemory(self.logical_device_data.device, self.index_buffer_memory, null);

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        c.vkDestroySemaphore(self.logical_device_data.device, self.sync_objects.image_available_semaphores[i], null);
        c.vkDestroySemaphore(self.logical_device_data.device, self.sync_objects.render_finished_semaphores[i], null);
        c.vkDestroyFence(self.logical_device_data.device, self.sync_objects.in_flight_fences[i], null);
    }

    c.vkDestroyCommandPool(self.logical_device_data.device, self.command_pool, null);
    c.vkDestroyCommandPool(self.logical_device_data.device, self.transfer_command_pool, null);

    c.vkDestroyPipeline(self.logical_device_data.device, self.graphics_pipeline_data.pipeline, null);
    c.vkDestroyPipelineLayout(self.logical_device_data.device, self.graphics_pipeline_data.layout, null);
    c.vkDestroyRenderPass(self.logical_device_data.device, self.graphics_pipeline_data.render_pass, null);

    c.vkDestroyDevice(self.logical_device_data.device, null);
    c.vkDestroySurfaceKHR(self.instance, self.surface, null);
    c.vkDestroyInstance(self.instance, null);

    zstbi.deinit();
}

fn createInstance(allocator: Allocator, required_extensions: [][*:0]const u8, app_info: c.VkApplicationInfo) !c.VkInstance {
    const extensions = try addDebugExtension(allocator, required_extensions);
    defer allocator.free(extensions);

    var create_info = c.VkInstanceCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @intCast(extensions.len),
        .ppEnabledExtensionNames = @ptrCast(extensions),
    };

    if (ENABLE_VALIDATION_LAYERS) {
        create_info.enabledLayerCount = VALIDATION_LAYERS.len;
        create_info.ppEnabledLayerNames = @ptrCast(&VALIDATION_LAYERS);

        var debug_create_info = createDebugMessengerCreateInfo();
        create_info.pNext = &debug_create_info;
    } else {
        create_info.enabledLayerCount = 0;
    }

    var instance: c.VkInstance = null;
    try utils.checkSuccess(c.vkCreateInstance(&create_info, null, &instance));

    return instance;
}

fn addDebugExtension(allocator: Allocator, required_extensions: [][*:0]const u8) ![][*:0]const u8 {
    var extensions = std.ArrayList([*:0]const u8).init(allocator);
    defer extensions.deinit();

    try extensions.appendSlice(required_extensions[0..required_extensions.len]);

    if (ENABLE_VALIDATION_LAYERS) {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    return try extensions.toOwnedSlice();
}

fn createDebugMessengerCreateInfo() c.VkDebugUtilsMessengerCreateInfoEXT {
    const create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = utils.debugCallback,
        .pUserData = null,
    };
    return create_info;
}

fn setupDebugCallback(instance: c.VkInstance) !c.VkDebugUtilsMessengerEXT {
    if (!ENABLE_VALIDATION_LAYERS) return;

    var create_info = createDebugMessengerCreateInfo();

    var debug_messenger: c.VkDebugUtilsMessengerEXT = null;
    try utils.checkSuccess(try createDebugMessenger(instance, &create_info, &debug_messenger));
    return debug_messenger;
}

fn createDebugMessenger(
    instance: c.VkInstance,
    p_create_info: *const c.VkDebugUtilsMessengerCreateInfoEXT,
    p_debug_messenger: *c.VkDebugUtilsMessengerEXT,
) !c.VkResult {
    const func_opt = @as(c.PFN_vkCreateDebugUtilsMessengerEXT, @ptrCast(c.vkGetInstanceProcAddr(
        instance,
        "vkCreateDebugUtilsMessengerEXT",
    )));

    if (func_opt) |func| {
        return func(instance, p_create_info, null, p_debug_messenger);
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
    func(self.instance, self.debug_messenger, null);
}

fn pickPhysicalDevice(allocator: Allocator, instance: c.VkInstance, surface: c.VkSurfaceKHR) !c.VkPhysicalDevice {
    var device_count: u32 = 0;
    try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &device_count, null));

    if (device_count == 0) {
        return error.NoGPUWithVulkanSupport;
    }

    const devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
    defer allocator.free(devices);

    try utils.checkSuccess(c.vkEnumeratePhysicalDevices(instance, &device_count, devices.ptr));

    return for (devices) |device| {
        if (try isDeviceSuitable(allocator, device, surface)) {
            break device;
        }
    } else return error.NoSuitableGPU;
}

fn isDeviceSuitable(allocator: Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !bool {
    const indices = try findQueueFamilies(allocator, physical_device, surface);
    const extensions_supported = try utils.checkDeviceExtensionSupport(allocator, physical_device, @constCast(&DEVICE_EXTENSIONS));

    var swapchain_adequate = false;
    if (extensions_supported) {
        var swapchain_support = try querySwapChainSupport(allocator, physical_device, surface);
        defer swapchain_support.deinit();

        swapchain_adequate = swapchain_support.formats.items.len > 0 and swapchain_support.present_modes.items.len > 0;
    }

    var supported_features: c.VkPhysicalDeviceFeatures = undefined;
    c.vkGetPhysicalDeviceFeatures(physical_device, &supported_features);

    return indices.isComplete() and extensions_supported and swapchain_adequate and supported_features.samplerAnisotropy != 0;
}

fn findQueueFamilies(allocator: Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !QueueFamilyIndices {
    var indices = QueueFamilyIndices.init();

    var queue_family_count: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

    const queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);

    c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);

    for (0.., queue_families) |i, family| {
        if ((family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
            indices.graphics_family = @truncate(i);
        } else if ((family.queueFlags & c.VK_QUEUE_TRANSFER_BIT) != 0) {
            indices.transfer_family = @truncate(i);
        }

        var present_support: c.VkBool32 = c.VK_FALSE;
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, @truncate(i), surface, &present_support));

        if (present_support == c.VK_TRUE) {
            indices.present_family = @truncate(i);
        }

        if (indices.isComplete()) {
            break;
        }
    }

    return indices;
}

fn createLogicalDevice(allocator: Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !LogicalDeviceData {
    const indices = try findQueueFamilies(allocator, physical_device, surface);

    var queue_create_infos = std.ArrayList(c.VkDeviceQueueCreateInfo).init(allocator);
    defer queue_create_infos.deinit();

    const all_queue_families = [_]u32{ indices.graphics_family.?, indices.present_family.?, indices.transfer_family.? };
    var unique_queue_families = std.ArrayList(u32).init(allocator);
    defer unique_queue_families.deinit();

    for (all_queue_families) |queue_family| {
        if (!utils.inSlice(u32, unique_queue_families.items, queue_family)) {
            try unique_queue_families.append(queue_family);
        }
    }

    const queue_priority: f32 = 1.0;
    for (unique_queue_families.items) |queue_family| {
        const queue_create_info: c.VkDeviceQueueCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queue_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        try queue_create_infos.append(queue_create_info);
    }

    var device_features: c.VkPhysicalDeviceFeatures = .{
        .samplerAnisotropy = c.VK_TRUE,
    };

    var device_create_info: c.VkDeviceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pQueueCreateInfos = queue_create_infos.items.ptr,
        .queueCreateInfoCount = @truncate(queue_create_infos.items.len),
        .pEnabledFeatures = &device_features,
        .enabledExtensionCount = @intCast(DEVICE_EXTENSIONS.len),
        .ppEnabledExtensionNames = &DEVICE_EXTENSIONS,
    };

    if (ENABLE_VALIDATION_LAYERS) {
        device_create_info.enabledLayerCount = VALIDATION_LAYERS.len;
        device_create_info.ppEnabledLayerNames = @ptrCast(&VALIDATION_LAYERS);
    } else {
        device_create_info.enabledLayerCount = 0;
    }

    var device: c.VkDevice = null;
    try utils.checkSuccess(c.vkCreateDevice(physical_device, &device_create_info, null, &device));

    var graphics_queue: c.VkQueue = null;
    c.vkGetDeviceQueue(device, indices.graphics_family.?, 0, &graphics_queue);

    var present_queue: c.VkQueue = null;
    c.vkGetDeviceQueue(device, indices.present_family.?, 0, &present_queue);

    var transfer_queue: c.VkQueue = null;
    c.vkGetDeviceQueue(device, indices.transfer_family.?, 0, &transfer_queue);

    return .{
        .device = device,
        .graphics_queue = .{ .queue = graphics_queue, .index = indices.graphics_family.? },
        .present_queue = .{ .queue = present_queue, .index = indices.present_family.? },
        .transfer_queue = .{ .queue = transfer_queue, .index = indices.transfer_family.? },
    };
}

fn createSurface(instance: c.VkInstance, window: *c.GLFWwindow) !c.VkSurfaceKHR {
    var surface: c.VkSurfaceKHR = null;
    try utils.checkSuccess(c.glfwCreateWindowSurface(instance, window, null, &surface));
    return surface;
}

fn querySwapChainSupport(allocator: Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapchainSupportDetails {
    var details = SwapchainSupportDetails.init(allocator);
    try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &details.capabilities));

    var format_count: u32 = 0;
    try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null));

    if (format_count != 0) {
        try details.formats.resize(format_count);
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, details.formats.items.ptr));
    }

    var present_mode_count: u32 = 0;
    try utils.checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null));

    if (present_mode_count != 0) {
        try details.present_modes.resize(present_mode_count);
        try utils.checkSuccess(c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, details.present_modes.items.ptr));
    }

    return details;
}

fn chooseSwapSurfaceFormat(available_formats: std.ArrayList(c.VkSurfaceFormatKHR)) c.VkSurfaceFormatKHR {
    for (available_formats.items) |format| {
        if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            return format;
        }
    }

    return available_formats.items[0];
}

fn chooseSwapPresentMode(available_present_modes: std.ArrayList(c.VkPresentModeKHR)) c.VkPresentModeKHR {
    for (available_present_modes.items) |present_mode| {
        if (present_mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
            return present_mode;
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

        var actual_extent = c.VkExtent2D{
            .width = @intCast(width),
            .height = @intCast(height),
        };

        actual_extent.width = std.math.clamp(actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
        actual_extent.height = std.math.clamp(actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
        return actual_extent;
    }
}

fn createSwapChain(allocator: Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR, device: c.VkDevice, window: *c.GLFWwindow) !SwapchainData {
    var swapchain_support_details = try querySwapChainSupport(allocator, physical_device, surface);
    defer swapchain_support_details.deinit();

    const surface_format = chooseSwapSurfaceFormat(swapchain_support_details.formats);
    const present_mode = chooseSwapPresentMode(swapchain_support_details.present_modes);
    const extent = chooseSwapExtent(swapchain_support_details.capabilities, window);

    var image_count = swapchain_support_details.capabilities.minImageCount + 1;
    const max_image_count = swapchain_support_details.capabilities.maxImageCount;

    if (max_image_count > 0 and image_count > max_image_count) {
        image_count = max_image_count;
    }

    var create_info: c.VkSwapchainCreateInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = surface,
        .minImageCount = image_count,
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .preTransform = swapchain_support_details.capabilities.currentTransform,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = c.VK_TRUE,
        .oldSwapchain = null,
    };

    const indices = try findQueueFamilies(allocator, physical_device, surface);
    const all_queue_families = [_]u32{ indices.graphics_family.?, indices.present_family.?, indices.transfer_family.? };
    var unique_queue_families = std.ArrayList(u32).init(allocator);
    defer unique_queue_families.deinit();

    for (all_queue_families) |queue_family| {
        if (!utils.inSlice(u32, unique_queue_families.items, queue_family)) {
            try unique_queue_families.append(queue_family);
        }
    }

    create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
    create_info.queueFamilyIndexCount = @intCast(unique_queue_families.items.len);
    create_info.pQueueFamilyIndices = unique_queue_families.items.ptr;

    var swapchain: c.VkSwapchainKHR = undefined;
    try utils.checkSuccess(c.vkCreateSwapchainKHR(device, &create_info, null, &swapchain));

    try utils.checkSuccess(c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, null));

    const swapchain_images = try allocator.alloc(c.VkImage, image_count);
    try utils.checkSuccess(c.vkGetSwapchainImagesKHR(device, swapchain, &image_count, swapchain_images.ptr));

    const swapchain_image_views = try allocator.alloc(c.VkImageView, image_count);

    for (0..swapchain_images.len) |i| {
        swapchain_image_views[i] = try createImageView(device, swapchain_images[i], surface_format.format, c.VK_IMAGE_ASPECT_COLOR_BIT);
    }

    return SwapchainData{
        .swapchain = swapchain,
        .image_format = surface_format.format,
        .extent = extent,
        .images = swapchain_images,
        .image_views = swapchain_image_views,
    };
}

fn createRenderPass(device: c.VkDevice, physical_device: c.VkPhysicalDevice, swapchain_image_format: c.VkFormat) !c.VkRenderPass {
    const color_attachment: c.VkAttachmentDescription = .{
        .format = swapchain_image_format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };

    const color_attachment_ref: c.VkAttachmentReference = .{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const depth_attachment: c.VkAttachmentDescription = .{
        .format = try utils.findDepthFormat(physical_device),
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    const depth_attachment_ref: c.VkAttachmentReference = .{
        .attachment = 1,
        .layout = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    const subpass: c.VkSubpassDescription = .{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
        .pDepthStencilAttachment = &depth_attachment_ref,
    };

    const dependency: c.VkSubpassDependency = .{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
        .srcAccessMask = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT | c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
    };

    const attachments = [_]c.VkAttachmentDescription{ color_attachment, depth_attachment };

    const render_pass_info: c.VkRenderPassCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = attachments.len,
        .pAttachments = &attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
    };

    var render_pass: c.VkRenderPass = undefined;
    try utils.checkSuccess(c.vkCreateRenderPass(device, &render_pass_info, null, &render_pass));

    return render_pass;
}

fn createGraphicsPipeline(allocator: Allocator, device: c.VkDevice, render_pass: c.VkRenderPass, descriptor_set_layout: c.VkDescriptorSetLayout) !GraphicsPipelineData {
    const vert = try utils.readFileToBuffer(allocator, "shaders/vert.spv");
    const frag = try utils.readFileToBuffer(allocator, "shaders/frag.spv");

    defer allocator.free(vert);
    defer allocator.free(frag);

    const vert_module = try utils.createShaderModule(vert, device);
    const frag_module = try utils.createShaderModule(frag, device);

    const vert_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vert_module,
        .pName = "main",
    };

    const frag_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = frag_module,
        .pName = "main",
    };

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{ vert_shader_stage_info, frag_shader_stage_info };

    const binding_description = Vertex.getBindingDescription();
    const attribute_descriptions = Vertex.getAttributeDescriptions();

    const vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &binding_description,
        .vertexAttributeDescriptionCount = attribute_descriptions.len,
        .pVertexAttributeDescriptions = &attribute_descriptions,
    };

    const input_assembly: c.VkPipelineInputAssemblyStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    const viewport_state: c.VkPipelineViewportStateCreateInfo = .{
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
        .frontFace = c.VK_FRONT_FACE_COUNTER_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
    };

    const multisampling: c.VkPipelineMultisampleStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
    };

    const color_blend_attachment: c.VkPipelineColorBlendAttachmentState = .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
    };

    const color_blending: c.VkPipelineColorBlendStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
    };

    const pipeline_layout_info: c.VkPipelineLayoutCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
    };

    var pipeline_layout: c.VkPipelineLayout = undefined;
    try utils.checkSuccess(c.vkCreatePipelineLayout(device, &pipeline_layout_info, null, &pipeline_layout));

    const dynamic_state: c.VkPipelineDynamicStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = @intCast(DYNAMIC_STATES.len),
        .pDynamicStates = @ptrCast(@constCast(&DYNAMIC_STATES)),
    };

    const depth_stencil: c.VkPipelineDepthStencilStateCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
        .stencilTestEnable = c.VK_FALSE,
    };

    const pipeline_info: c.VkGraphicsPipelineCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_input_info,
        .pInputAssemblyState = &input_assembly,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer,
        .pMultisampleState = &multisampling,
        .pColorBlendState = &color_blending,
        .pDynamicState = &dynamic_state,
        .pDepthStencilState = &depth_stencil,
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0,
    };

    var graphics_pipeline: c.VkPipeline = undefined;
    try utils.checkSuccess(c.vkCreateGraphicsPipelines(device, null, 1, &pipeline_info, null, &graphics_pipeline));

    c.vkDestroyShaderModule(device, vert_module, null);
    c.vkDestroyShaderModule(device, frag_module, null);

    return GraphicsPipelineData{
        .layout = pipeline_layout,
        .render_pass = render_pass,
        .pipeline = graphics_pipeline,
    };
}

fn createFrameBuffers(allocator: Allocator, device: c.VkDevice, render_pass: c.VkRenderPass, swapchain_data: SwapchainData, depth_image_view: c.VkImageView) ![]c.VkFramebuffer {
    const swapchain_frame_buffers = try allocator.alloc(c.VkFramebuffer, swapchain_data.image_views.len);

    for (0..swapchain_data.image_views.len) |i| {
        const attachments = [_]c.VkImageView{ swapchain_data.image_views[i], depth_image_view };

        const frame_buffer_create_info: c.VkFramebufferCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = render_pass,
            .attachmentCount = attachments.len,
            .pAttachments = &attachments,
            .width = swapchain_data.extent.width,
            .height = swapchain_data.extent.height,
            .layers = 1,
        };

        try utils.checkSuccess(c.vkCreateFramebuffer(device, &frame_buffer_create_info, null, &swapchain_frame_buffers[i]));
    }

    return swapchain_frame_buffers;
}

fn createCommandPool(device: c.VkDevice, queue_index: u32, flags: c.VkCommandPoolCreateFlagBits) !c.VkCommandPool {
    const pool_info: c.VkCommandPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = flags,
        .queueFamilyIndex = queue_index,
    };

    var command_pool: c.VkCommandPool = undefined;
    try utils.checkSuccess(c.vkCreateCommandPool(device, &pool_info, null, &command_pool));

    return command_pool;
}

fn createCommandBuffers(allocator: Allocator, device: c.VkDevice, command_pool: c.VkCommandPool) ![]c.VkCommandBuffer {
    const command_buffers = try allocator.alloc(c.VkCommandBuffer, MAX_FRAMES_IN_FLIGHT);

    const alloc_info: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = command_pool,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = @intCast(command_buffers.len),
    };

    try utils.checkSuccess(c.vkAllocateCommandBuffers(device, &alloc_info, @ptrCast(command_buffers.ptr)));

    return command_buffers;
}

pub fn recordCommandBuffer(self: Renderer, command_buffer: c.VkCommandBuffer, image_index: u32) !void {
    const begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    };

    try utils.checkSuccess(c.vkBeginCommandBuffer(command_buffer, &begin_info));

    const clear_values = [_]c.VkClearValue{
        .{
            .color = c.VkClearColorValue{ .float32 = [_]f32{ 0, 0, 0, 1 } },
        },
        .{
            .depthStencil = c.VkClearDepthStencilValue{ .depth = 1.0, .stencil = 0 },
        },
    };
    const render_pass_info: c.VkRenderPassBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = self.graphics_pipeline_data.render_pass,
        .framebuffer = self.frame_buffers[image_index],
        .renderArea = .{
            .offset = c.VkOffset2D{ .x = 0, .y = 0 },
            .extent = self.swapchain_data.extent,
        },
        .clearValueCount = clear_values.len,
        .pClearValues = &clear_values,
    };

    c.vkCmdBeginRenderPass(command_buffer, &render_pass_info, c.VK_SUBPASS_CONTENTS_INLINE);

    c.vkCmdBindPipeline(command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphics_pipeline_data.pipeline);

    const viewport: c.VkViewport = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(self.swapchain_data.extent.width),
        .height = @floatFromInt(self.swapchain_data.extent.height),
        .minDepth = 0,
        .maxDepth = 1,
    };

    c.vkCmdSetViewport(command_buffer, 0, 1, &viewport);

    const scissor: c.VkRect2D = .{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = self.swapchain_data.extent,
    };

    c.vkCmdSetScissor(command_buffer, 0, 1, &scissor);

    const vertex_buffers = [_]c.VkBuffer{self.vertex_buffer};
    const offsets = [_]c.VkDeviceSize{0};
    c.vkCmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers, &offsets);

    c.vkCmdBindIndexBuffer(command_buffer, self.index_buffer, 0, c.VK_INDEX_TYPE_UINT32);
    c.vkCmdBindDescriptorSets(command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.graphics_pipeline_data.layout, 0, 1, &self.descriptor_sets[self.current_frame], 0, null);
    c.vkCmdDrawIndexed(command_buffer, @intCast(self.indices.len), 1, 0, 0, 0);
    c.vkCmdEndRenderPass(command_buffer);

    try utils.checkSuccess(c.vkEndCommandBuffer(command_buffer));
}

fn createSyncObjects(device: c.VkDevice) !SyncObjects {
    var sync_objects = SyncObjects{
        .image_available_semaphores = undefined,
        .render_finished_semaphores = undefined,
        .in_flight_fences = undefined,
    };

    const semaphore_info: c.VkSemaphoreCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    };

    const fence_info: c.VkFenceCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        try utils.checkSuccess(c.vkCreateSemaphore(device, &semaphore_info, null, &sync_objects.image_available_semaphores[i]));
        try utils.checkSuccess(c.vkCreateSemaphore(device, &semaphore_info, null, &sync_objects.render_finished_semaphores[i]));
        try utils.checkSuccess(c.vkCreateFence(device, &fence_info, null, &sync_objects.in_flight_fences[i]));
    }

    return sync_objects;
}

pub fn drawFrame(self: *Renderer, window: *c.GLFWwindow) !void {
    const current_frame_time = try time.Instant.now();
    // const delta: f32 = @as(f32, @floatFromInt(current_frame_time.since(self.last_frame_time))) / 1_000_000_000;
    self.last_frame_time = current_frame_time;

    // std.debug.print("delta: {d}\n", .{delta});

    const in_flight_fence = self.sync_objects.in_flight_fences[self.current_frame];
    const image_available_semaphore = self.sync_objects.image_available_semaphores[self.current_frame];
    const render_finished_semaphore = self.sync_objects.render_finished_semaphores[self.current_frame];

    const command_buffer = self.command_buffers[self.current_frame];

    try utils.checkSuccess(c.vkWaitForFences(self.logical_device_data.device, 1, &in_flight_fence, c.VK_TRUE, maxInt(u64)));

    var image_index: u32 = undefined;
    const aquire_result = c.vkAcquireNextImageKHR(self.logical_device_data.device, self.swapchain_data.swapchain, maxInt(u64), image_available_semaphore, null, &image_index);

    if (aquire_result == c.VK_ERROR_OUT_OF_DATE_KHR) {
        try self.recreateSwapchain(window);
        return;
    } else if (aquire_result != c.VK_SUCCESS and aquire_result != c.VK_SUBOPTIMAL_KHR) {
        return error.VulkanFailedToAquireSwapchainImage;
    }

    try self.updateUniformBuffer();

    try utils.checkSuccess(c.vkResetFences(self.logical_device_data.device, 1, &in_flight_fence));

    try utils.checkSuccess(c.vkResetCommandBuffer(command_buffer, 0));

    try self.recordCommandBuffer(command_buffer, image_index);

    const wait_semaphores = [_]c.VkSemaphore{image_available_semaphore};
    const wait_stages = [_]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};

    const signal_semaphores = [_]c.VkSemaphore{render_finished_semaphore};

    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &wait_semaphores,
        .pWaitDstStageMask = &wait_stages,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signal_semaphores,
    };

    try utils.checkSuccess(c.vkQueueSubmit(self.logical_device_data.graphics_queue.queue.?, 1, &submit_info, in_flight_fence));

    const swapchains = [_]c.VkSwapchainKHR{self.swapchain_data.swapchain};
    const presentInfo: c.VkPresentInfoKHR = .{
        .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signal_semaphores,
        .swapchainCount = 1,
        .pSwapchains = &swapchains,
        .pImageIndices = &image_index,
    };

    const present_result = c.vkQueuePresentKHR(self.logical_device_data.present_queue.queue, &presentInfo);

    if (present_result == c.VK_ERROR_OUT_OF_DATE_KHR or present_result == c.VK_SUBOPTIMAL_KHR or self.frame_buffer_resized) {
        self.frame_buffer_resized = false;
        try self.recreateSwapchain(window);
    } else if (present_result != c.VK_SUCCESS) {
        return error.VulkanFailedToPresentSwapchainImage;
    }

    self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
}

pub fn waitForDevice(self: Renderer) !void {
    try utils.checkSuccess(c.vkDeviceWaitIdle(self.logical_device_data.device));
}

fn recreateSwapchain(self: *Renderer, window: *c.GLFWwindow) !void {
    var width: c_int = 0;
    var height: c_int = 0;
    c.glfwGetFramebufferSize(window, &width, &height);

    while (width == 0 or height == 0) {
        c.glfwGetFramebufferSize(window, &width, &height);
        c.glfwWaitEvents();
    }

    try self.waitForDevice();

    self.destroySwapchain();

    self.swapchain_data = try createSwapChain(std.heap.c_allocator, self.physical_device, self.surface, self.logical_device_data.device, window);
    self.depth_resources = try createDepthResources(self.logical_device_data.device, self.physical_device, self.swapchain_data.extent);
    self.frame_buffers = try createFrameBuffers(std.heap.c_allocator, self.logical_device_data.device, self.graphics_pipeline_data.render_pass, self.swapchain_data, self.depth_resources.image_view);
}

fn createVertexBuffer(device: c.VkDevice, physical_device: c.VkPhysicalDevice, vertices: []Vertex, transfer_command_pool: c.VkCommandPool, transfer_queue: c.VkQueue) !BufferData {
    const buffer_size = @sizeOf(Vertex) * vertices.len;

    var staging_buffer: c.VkBuffer = undefined;
    var staging_buffer_memory: c.VkDeviceMemory = undefined;
    try createBuffer(device, physical_device, buffer_size, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &staging_buffer, &staging_buffer_memory);

    var data: [*]Vertex = undefined;
    try utils.checkSuccess(c.vkMapMemory(device, staging_buffer_memory, 0, buffer_size, 0, @ptrCast(&data)));

    @memcpy(data, vertices);

    c.vkUnmapMemory(device, staging_buffer_memory);

    var vertex_buffer: c.VkBuffer = undefined;
    var vertex_buffer_memory: c.VkDeviceMemory = undefined;
    try createBuffer(device, physical_device, buffer_size, c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &vertex_buffer, &vertex_buffer_memory);

    try copyBuffer(device, staging_buffer, vertex_buffer, buffer_size, transfer_command_pool, transfer_queue);

    c.vkDestroyBuffer(device, staging_buffer, null);
    c.vkFreeMemory(device, staging_buffer_memory, null);

    return .{ .buffer = vertex_buffer, .memory = vertex_buffer_memory };
}

fn findMemoryType(physical_device: c.VkPhysicalDevice, type_filter: u32, properties: c.VkMemoryPropertyFlags) u32 {
    var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
    c.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

    for (0..mem_properties.memoryTypeCount) |i| {
        if ((type_filter & std.math.shl(u32, 1, i) > 0) and (mem_properties.memoryTypes[i].propertyFlags & properties) == properties) {
            return @intCast(i);
        }
    }

    @panic("Failed to find suitable memory type!");
}

fn createBuffer(device: c.VkDevice, physical_device: c.VkPhysicalDevice, size: c.VkDeviceSize, usage: c.VkBufferUsageFlags, properties: c.VkMemoryPropertyFlags, buffer: *c.VkBuffer, buffer_memory: *c.VkDeviceMemory) !void {
    const buffer_info: c.VkBufferCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
    };

    try utils.checkSuccess(c.vkCreateBuffer(device, &buffer_info, null, buffer));

    var requirements: c.VkMemoryRequirements = undefined;
    c.vkGetBufferMemoryRequirements(device, buffer.*, &requirements);

    const alloc_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = requirements.size,
        .memoryTypeIndex = findMemoryType(
            physical_device,
            requirements.memoryTypeBits,
            properties,
        ),
    };

    try utils.checkSuccess(c.vkAllocateMemory(device, &alloc_info, null, buffer_memory));
    try utils.checkSuccess(c.vkBindBufferMemory(device, buffer.*, buffer_memory.*, 0));
}

fn copyBuffer(device: c.VkDevice, src_buffer: c.VkBuffer, dst_buffer: c.VkBuffer, size: c.VkDeviceSize, command_pool: c.VkCommandPool, transfer_queue: c.VkQueue) !void {
    const command_buffer = try beginSingleTimeCommands(device, command_pool);

    const copy_region: c.VkBufferCopy = .{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    c.vkCmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region);

    try endSingleTimeCommands(device, command_pool, command_buffer, transfer_queue);
}

fn createIndexBuffer(device: c.VkDevice, physical_device: c.VkPhysicalDevice, indices: []u32, transfer_command_pool: c.VkCommandPool, transfer_queue: c.VkQueue) !BufferData {
    const buffer_size = @sizeOf(u32) * indices.len;
    var staging_buffer: c.VkBuffer = undefined;
    var staging_buffer_memory: c.VkDeviceMemory = undefined;
    try createBuffer(device, physical_device, buffer_size, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &staging_buffer, &staging_buffer_memory);

    var data: [*]u32 = undefined;
    try utils.checkSuccess(c.vkMapMemory(device, staging_buffer_memory, 0, buffer_size, 0, @ptrCast(&data)));

    @memcpy(data, indices);

    c.vkUnmapMemory(device, staging_buffer_memory);

    var index_buffer: c.VkBuffer = undefined;
    var index_buffer_memory: c.VkDeviceMemory = undefined;
    try createBuffer(device, physical_device, buffer_size, c.VK_BUFFER_USAGE_TRANSFER_DST_BIT | c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &index_buffer, &index_buffer_memory);

    try copyBuffer(device, staging_buffer, index_buffer, buffer_size, transfer_command_pool, transfer_queue);

    c.vkDestroyBuffer(device, staging_buffer, null);
    c.vkFreeMemory(device, staging_buffer_memory, null);

    return .{ .buffer = index_buffer, .memory = index_buffer_memory };
}

fn createDescriptorSetLayout(device: c.VkDevice) !c.VkDescriptorSetLayout {
    const ubo_layout_binding: c.VkDescriptorSetLayoutBinding = .{
        .binding = 0,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = 1,
        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
    };

    const sampler_layout_binding: c.VkDescriptorSetLayoutBinding = .{
        .binding = 1,
        .descriptorCount = 1,
        .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .pImmutableSamplers = null,
        .stageFlags = c.VK_SHADER_STAGE_FRAGMENT_BIT,
    };

    var bindings = [_]c.VkDescriptorSetLayoutBinding{ ubo_layout_binding, sampler_layout_binding };

    const layout_info: c.VkDescriptorSetLayoutCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = bindings.len,
        .pBindings = &bindings,
    };

    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    try utils.checkSuccess(c.vkCreateDescriptorSetLayout(device, &layout_info, null, &descriptor_set_layout));

    return descriptor_set_layout;
}

fn createUniformBuffers(device: c.VkDevice, physical_device: c.VkPhysicalDevice) !UniformBufferData {
    const buffer_size: c.VkDeviceSize = @sizeOf(UniformBufferObject);

    var uniform_buffer_data: UniformBufferData = .{
        .buffers = undefined,
        .buffers_memory = undefined,
    };

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        try createBuffer(device, physical_device, buffer_size, c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &uniform_buffer_data.buffers[i], &uniform_buffer_data.buffers_memory[i]);
    }

    return uniform_buffer_data;
}

fn updateUniformBuffer(self: *Renderer) !void {
    const current_time = try time.Instant.now();
    const time_since_start: f32 = @as(f32, @floatFromInt(current_time.since(self.start_time))) / 1_000_000_000;
    const angle = time_since_start * std.math.degreesToRadians(90.0);

    var ubo: UniformBufferObject = .{
        .model = zmath.rotationZ(angle),
        .view = zmath.lookAtRh(zmath.f32x4(2.0, 2.0, 2.0, 1.0), zmath.f32x4(0.0, 0.0, 0.0, 1.0), zmath.f32x4(0.0, 0.0, 1.0, 0.0)),
        .proj = zmath.perspectiveFovRh(
            std.math.degreesToRadians(45.0),
            @as(f32, @floatFromInt(self.swapchain_data.extent.width)) / @as(f32, @floatFromInt(self.swapchain_data.extent.height)),
            0.1,
            100.0,
        ),
    };

    ubo.proj[1][1] *= -1;

    var data: [*]u8 = undefined;
    try utils.checkSuccess(c.vkMapMemory(self.logical_device_data.device, self.uniform_buffers.buffers_memory[self.current_frame], 0, @sizeOf(UniformBufferObject), 0, @ptrCast(&data)));

    @memcpy(data, std.mem.asBytes(&ubo));

    c.vkUnmapMemory(self.logical_device_data.device, self.uniform_buffers.buffers_memory[self.current_frame]);
}

fn createDescriptorPool(device: c.VkDevice) !c.VkDescriptorPool {
    const ubo_pool_size: c.VkDescriptorPoolSize = .{
        .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
        .descriptorCount = MAX_FRAMES_IN_FLIGHT,
    };

    const sampler_pool_size: c.VkDescriptorPoolSize = .{
        .type = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
        .descriptorCount = MAX_FRAMES_IN_FLIGHT,
    };

    var descriptor_pools = [_]c.VkDescriptorPoolSize{ ubo_pool_size, sampler_pool_size };

    const pool_info: c.VkDescriptorPoolCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = descriptor_pools.len,
        .pPoolSizes = &descriptor_pools,
        .maxSets = MAX_FRAMES_IN_FLIGHT,
    };

    var descriptor_pool: c.VkDescriptorPool = undefined;
    try utils.checkSuccess(c.vkCreateDescriptorPool(device, &pool_info, null, &descriptor_pool));

    return descriptor_pool;
}

fn createDescriptorSets(device: c.VkDevice, descriptor_set_layout: c.VkDescriptorSetLayout, descriptor_pool: c.VkDescriptorPool, uniform_buffer_data: UniformBufferData, image_view: c.VkImageView, sampler: c.VkSampler) ![MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSet {
    var layouts: [MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSetLayout = .{descriptor_set_layout} ** MAX_FRAMES_IN_FLIGHT;

    const alloc_info: c.VkDescriptorSetAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = MAX_FRAMES_IN_FLIGHT,
        .pSetLayouts = &layouts,
    };

    var descriptor_sets: [MAX_FRAMES_IN_FLIGHT]c.VkDescriptorSet = undefined;
    try utils.checkSuccess(c.vkAllocateDescriptorSets(device, &alloc_info, &descriptor_sets));

    for (0..MAX_FRAMES_IN_FLIGHT) |i| {
        const buffer_info: c.VkDescriptorBufferInfo = .{
            .buffer = uniform_buffer_data.buffers[i],
            .offset = 0,
            .range = @sizeOf(UniformBufferObject),
        };

        const image_info: c.VkDescriptorImageInfo = .{
            .imageLayout = c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            .imageView = image_view,
            .sampler = sampler,
        };

        const buffer_descriptor_write: c.VkWriteDescriptorSet = .{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptor_sets[i],
            .dstBinding = 0,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .pBufferInfo = &buffer_info,
        };

        const image_descriptor_write: c.VkWriteDescriptorSet = .{
            .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = descriptor_sets[i],
            .dstBinding = 1,
            .dstArrayElement = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
            .descriptorCount = 1,
            .pImageInfo = &image_info,
        };

        var descriptor_writes = [_]c.VkWriteDescriptorSet{ buffer_descriptor_write, image_descriptor_write };

        c.vkUpdateDescriptorSets(device, descriptor_writes.len, &descriptor_writes, 0, null);
    }

    return descriptor_sets;
}

fn createTextureImage(path: [:0]const u8, device: c.VkDevice, physical_device: c.VkPhysicalDevice, command_pool: c.VkCommandPool, queue: c.VkQueue) !TextureImageData {
    var image_data = try zstbi.Image.loadFromFile(path, 4);
    defer image_data.deinit();

    const image_size = image_data.width * image_data.height * 4;

    var staging_buffer: c.VkBuffer = undefined;
    var staging_buffer_memory: c.VkDeviceMemory = undefined;

    try createBuffer(device, physical_device, image_size, c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT, c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, &staging_buffer, &staging_buffer_memory);

    var data: [*]u8 = undefined;
    try utils.checkSuccess(c.vkMapMemory(device, staging_buffer_memory, 0, image_size, 0, @ptrCast(&data)));

    @memcpy(data, image_data.data);

    c.vkUnmapMemory(device, staging_buffer_memory);

    var image: c.VkImage = undefined;
    var image_memory: c.VkDeviceMemory = undefined;

    try createImage(device, physical_device, image_data.width, image_data.height, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_TILING_OPTIMAL, c.VK_IMAGE_USAGE_TRANSFER_DST_BIT | c.VK_IMAGE_USAGE_SAMPLED_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &image, &image_memory);

    try transitionImageLayout(device, command_pool, queue, image, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_LAYOUT_UNDEFINED, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
    try copyBufferToImage(device, command_pool, queue, staging_buffer, image, image_data.width, image_data.height);

    try transitionImageLayout(device, command_pool, queue, image, c.VK_FORMAT_R8G8B8A8_SRGB, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);

    c.vkDestroyBuffer(device, staging_buffer, null);
    c.vkFreeMemory(device, staging_buffer_memory, null);

    return .{ .image = image, .image_memory = image_memory };
}

fn createImage(device: c.VkDevice, physical_device: c.VkPhysicalDevice, width: u32, height: u32, format: c.VkFormat, tiling: c.VkImageTiling, usage: c.VkImageUsageFlags, properties: c.VkMemoryPropertyFlags, image: *c.VkImage, image_memory: *c.VkDeviceMemory) !void {
    const image_info: c.VkImageCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
        .imageType = c.VK_IMAGE_TYPE_2D,
        .extent = .{
            .width = width,
            .height = height,
            .depth = 1,
        },
        .mipLevels = 1,
        .arrayLayers = 1,
        .format = format,
        .tiling = tiling,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .usage = usage,
        .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
    };

    try utils.checkSuccess(c.vkCreateImage(device, &image_info, null, image));

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(device, image.*, &mem_requirements);

    const alloc_info: c.VkMemoryAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            properties,
        ),
    };

    try utils.checkSuccess(c.vkAllocateMemory(device, &alloc_info, null, image_memory));
    try utils.checkSuccess(c.vkBindImageMemory(device, image.*, image_memory.*, 0));
}

fn beginSingleTimeCommands(device: c.VkDevice, command_pool: c.VkCommandPool) !c.VkCommandBuffer {
    const allocInfo: c.VkCommandBufferAllocateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandPool = command_pool,
        .commandBufferCount = 1,
    };

    var command_buffer: c.VkCommandBuffer = undefined;
    try utils.checkSuccess(c.vkAllocateCommandBuffers(device, &allocInfo, &command_buffer));

    const begin_info: c.VkCommandBufferBeginInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    try utils.checkSuccess(c.vkBeginCommandBuffer(command_buffer, &begin_info));

    return command_buffer;
}

fn endSingleTimeCommands(device: c.VkDevice, command_pool: c.VkCommandPool, command_buffer: c.VkCommandBuffer, queue: c.VkQueue) !void {
    try utils.checkSuccess(c.vkEndCommandBuffer(command_buffer));

    const submit_info: c.VkSubmitInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
    };
    try utils.checkSuccess(c.vkQueueSubmit(queue, 1, &submit_info, null));
    try utils.checkSuccess(c.vkQueueWaitIdle(queue));

    c.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
}

fn transitionImageLayout(device: c.VkDevice, command_pool: c.VkCommandPool, queue: c.VkQueue, image: c.VkImage, format: c.VkFormat, old_layout: c.VkImageLayout, new_layout: c.VkImageLayout) !void {
    _ = format;

    const command_buffer = try beginSingleTimeCommands(device, command_pool);

    var barrier: c.VkImageMemoryBarrier = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
        .subresourceRange = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .srcAccessMask = 0,
        .dstAccessMask = 0,
    };

    var source_stage: c.VkPipelineStageFlags = undefined;
    var destination_stage: c.VkPipelineStageFlags = undefined;

    if (old_layout == c.VK_IMAGE_LAYOUT_UNDEFINED and new_layout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
        barrier.srcAccessMask = 0;
        barrier.dstAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;

        source_stage = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
        destination_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
    } else if (old_layout == c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and new_layout == c.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
        barrier.srcAccessMask = c.VK_ACCESS_TRANSFER_WRITE_BIT;
        barrier.dstAccessMask = c.VK_ACCESS_SHADER_READ_BIT;

        source_stage = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
        destination_stage = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
    } else {
        return error.UnsupportedLayoutTransition;
    }

    c.vkCmdPipelineBarrier(command_buffer, source_stage, destination_stage, 0, 0, null, 0, null, 1, &barrier);

    try endSingleTimeCommands(device, command_pool, command_buffer, queue);
}

fn copyBufferToImage(device: c.VkDevice, command_pool: c.VkCommandPool, queue: c.VkQueue, buffer: c.VkBuffer, image: c.VkImage, width: u32, height: u32) !void {
    const command_buffer = try beginSingleTimeCommands(device, command_pool);

    const region: c.VkBufferImageCopy = .{
        .bufferOffset = 0,
        .bufferRowLength = 0,
        .bufferImageHeight = 0,
        .imageSubresource = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .mipLevel = 0,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
        .imageOffset = c.VkOffset3D{ .x = 0, .y = 0, .z = 0 },
        .imageExtent = c.VkExtent3D{ .width = width, .height = height, .depth = 1 },
    };

    c.vkCmdCopyBufferToImage(command_buffer, buffer, image, c.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

    try endSingleTimeCommands(device, command_pool, command_buffer, queue);
}

fn createImageView(device: c.VkDevice, image: c.VkImage, format: c.VkFormat, aspect_flags: c.VkImageAspectFlags) !c.VkImageView {
    var image_view_create_info: c.VkImageViewCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .image = image,
        .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .subresourceRange = .{
            .aspectMask = aspect_flags,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    var image_view: c.VkImageView = undefined;
    try utils.checkSuccess(c.vkCreateImageView(device, &image_view_create_info, null, &image_view));

    return image_view;
}

fn createTextureSampler(device: c.VkDevice, physical_device: c.VkPhysicalDevice) !c.VkSampler {
    var device_properties: c.VkPhysicalDeviceProperties = undefined;
    c.vkGetPhysicalDeviceProperties(physical_device, &device_properties);

    var sampler_create_info: c.VkSamplerCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
        .magFilter = c.VK_FILTER_LINEAR,
        .minFilter = c.VK_FILTER_LINEAR,
        .addressModeU = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeV = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .addressModeW = c.VK_SAMPLER_ADDRESS_MODE_REPEAT,
        .anisotropyEnable = c.VK_TRUE,
        .maxAnisotropy = device_properties.limits.maxSamplerAnisotropy,
        .borderColor = c.VK_BORDER_COLOR_INT_OPAQUE_BLACK,
        .unnormalizedCoordinates = c.VK_FALSE,
        .compareEnable = c.VK_FALSE,
        .compareOp = c.VK_COMPARE_OP_ALWAYS,
        .mipmapMode = c.VK_SAMPLER_MIPMAP_MODE_LINEAR,
    };

    var texture_sampler: c.VkSampler = undefined;
    try utils.checkSuccess(c.vkCreateSampler(device, &sampler_create_info, null, &texture_sampler));

    return texture_sampler;
}

fn createDepthResources(device: c.VkDevice, physical_device: c.VkPhysicalDevice, swapchain_extent: c.VkExtent2D) !DepthResources {
    const depth_format = try utils.findDepthFormat(physical_device);

    var depth_image: c.VkImage = undefined;
    var depth_image_memory: c.VkDeviceMemory = undefined;

    try createImage(device, physical_device, swapchain_extent.width, swapchain_extent.height, depth_format, c.VK_IMAGE_TILING_OPTIMAL, c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT, c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, &depth_image, &depth_image_memory);

    const depth_image_view = try createImageView(device, depth_image, depth_format, c.VK_IMAGE_ASPECT_DEPTH_BIT);

    return .{
        .image = depth_image,
        .image_memory = depth_image_memory,
        .image_view = depth_image_view,
    };
}

fn loadObjModel(allocator: Allocator, path: [:0]const u8) !ModelData {
    var vertices = std.ArrayList(Vertex).init(allocator);
    var indices = std.ArrayList(u32).init(allocator);

    // const vertices_data = [_]Vertex{
    //     .{ .pos = .{ -0.5, -0.5, 0.0 }, .color = .{ 1.0, 0.0, 0.0 }, .tex_coord = .{ 1.0, 0.0 } },
    //     .{ .pos = .{ 0.5, -0.5, 0.0 }, .color = .{ 0.0, 1.0, 0.0 }, .tex_coord = .{ 0.0, 0.0 } },
    //     .{ .pos = .{ 0.5, 0.5, 0.0 }, .color = .{ 0.0, 0.0, 1.0 }, .tex_coord = .{ 0.0, 1.0 } },
    //     .{ .pos = .{ -0.5, 0.5, 0.0 }, .color = .{ 1.0, 1.0, 1.0 }, .tex_coord = .{ 1.0, 1.0 } },
    //
    //     .{ .pos = .{ -0.5, -0.5, -0.5 }, .color = .{ 1.0, 0.0, 0.0 }, .tex_coord = .{ 1.0, 0.0 } },
    //     .{ .pos = .{ 0.5, -0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 }, .tex_coord = .{ 0.0, 0.0 } },
    //     .{ .pos = .{ 0.5, 0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 }, .tex_coord = .{ 0.0, 1.0 } },
    //     .{ .pos = .{ -0.5, 0.5, -0.5 }, .color = .{ 1.0, 1.0, 1.0 }, .tex_coord = .{ 1.0, 1.0 } },
    // };

    // // zig fmt: off
    // const indices_data = [_]u32{
    //     0, 1, 2, 2, 3, 0,
    //     4, 5, 6, 6, 7, 4
    // };
    // // zig fmt: on

    // for (vertices_data) |vertice| {
    //     try vertices.append(vertice);
    // }
    //
    // for (indices_data) |indice| {
    //     try indices.append(indice);
    // }

    var obj_vertex_data = std.ArrayList([3]f32).init(allocator);
    defer obj_vertex_data.deinit();

    var obj_tex_coord_data = std.ArrayList([2]f32).init(allocator);
    defer obj_tex_coord_data.deinit();

    var obj_faces_data = std.ArrayList(utils.ObjFace).init(allocator);
    defer obj_faces_data.deinit();

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const data = try utils.parseObjLine(allocator, line);
        blk: switch (data) {
            .Vertex => |v| try obj_vertex_data.append(v),
            .TexCoord => |t| try obj_tex_coord_data.append(t),
            .Face => |f| try obj_faces_data.appendSlice(f),
            else => break :blk,
        }
    }

    for (obj_faces_data.items) |face| {
        const pos = obj_vertex_data.items[@intCast(face.vertex_index - 1)];
        const tex_coord = obj_tex_coord_data.items[@intCast(face.tex_coord_index - 1)];

        try vertices.append(Vertex{
            .pos = pos,
            .tex_coord = .{ tex_coord[0], 1 - tex_coord[1] },
            .color = .{ 1, 1, 1 },
        });

        try indices.append(@intCast(indices.items.len));
    }

    return .{
        .vertices = try vertices.toOwnedSlice(),
        .indices = try indices.toOwnedSlice(),
    };
}
