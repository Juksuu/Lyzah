const std = @import("std");
const c = @import("../c.zig");

const Allocator = std.mem.Allocator;

pub fn checkSuccess(result: c.VkResult) !void {
    switch (result) {
        c.VK_SUCCESS => {},
        else => return error.VulkanUnexpectedError,
    }
}

pub fn checkValidationLayerSupport(allocator: Allocator, layers: [][*:0]const u8) !bool {
    var layerCount: u32 = undefined;
    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, null));

    const availableLayers = try allocator.alloc(c.VkLayerProperties, layerCount);
    defer allocator.free(availableLayers);

    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr));

    for (layers) |layerName| {
        var layerFound = false;

        for (availableLayers) |layerProperties| {
            const layerNameWithLength = std.mem.span(layerName);
            const length = @min(layerNameWithLength.len, layerProperties.layerName.len);
            if (std.mem.eql(u8, layerNameWithLength, layerProperties.layerName[0..length])) {
                layerFound = true;
                break;
            }
        }

        if (!layerFound) {
            return false;
        }
    }

    return true;
}

pub fn checkDeviceExtensionSupport(allocator: Allocator, device: c.VkPhysicalDevice, extensions: [][*:0]const u8) !bool {
    var extensionCount: u32 = undefined;
    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, null));

    const availableExtensions = try allocator.alloc(c.VkExtensionProperties, extensionCount);
    defer allocator.free(availableExtensions);

    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extensionCount, availableExtensions.ptr));

    for (extensions) |name| {
        var found = false;

        for (availableExtensions) |extension| {
            const extensionNameWithLength = std.mem.span(name);
            const length = @min(extensionNameWithLength.len, extension.extensionName.len);
            if (std.mem.eql(u8, extensionNameWithLength, extension.extensionName[0..length])) {
                found = true;
                break;
            }
        }

        if (!found) {
            return false;
        }
    }

    return true;
}

pub fn debugCallback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msg_type: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = user_data;
    const severity_str = switch (severity) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        else => "unknown",
    };

    const type_str = switch (msg_type) {
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        c.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "device address",
        else => "unknown",
    };

    const message: [*c]const u8 = if (callback_data) |cb_data| cb_data.pMessage else "NO MESSAGE!";
    std.debug.print("{s}|{s}: {s}\n", .{ severity_str, type_str, message });

    if (severity >= c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        @panic("Unrecoverable vulkan error.");
    }

    return c.VK_FALSE;
}

pub fn readFileToBuffer(allocator: Allocator, filePath: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only });

    const fileSize = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, fileSize);

    _ = try file.read(buffer);

    return buffer;
}

pub fn createShaderModule(code: []const u8, device: c.VkDevice) !c.VkShaderModule {
    const createInfo: c.VkShaderModuleCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @alignCast(@ptrCast(code.ptr)),
    };

    var shaderModule: c.VkShaderModule = undefined;
    try checkSuccess(c.vkCreateShaderModule(device, &createInfo, null, &shaderModule));

    return shaderModule;
}
