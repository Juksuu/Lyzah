const std = @import("std");
const c = @import("../c.zig");

pub inline fn checkSuccess(result: c.VkResult) !void {
    switch (result) {
        c.VK_SUCCESS => {},
        else => return error.VulkanUnexpectedError,
    }
}

pub inline fn checkValidationLayerSupport(layers: [][*:0]const u8) !bool {
    var allocator = std.heap.c_allocator;

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
