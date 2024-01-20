const std = @import("std");
const vk = @import("vulkan");

pub inline fn checkSuccess(result: vk.VkResult) !void {
    switch (result) {
        vk.VK_SUCCESS => {},
        else => return error.VulkanUnexpectedError,
    }
}

pub inline fn checkValidationLayerSupport(layers: [][*:0]const u8) !bool {
    var allocator = std.heap.c_allocator;

    var layerCount: u32 = undefined;
    try checkSuccess(vk.vkEnumerateInstanceLayerProperties(&layerCount, null));

    const availableLayers = try allocator.alloc(vk.VkLayerProperties, layerCount);
    defer allocator.free(availableLayers);

    try checkSuccess(vk.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.ptr));

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
    severity: vk.VkDebugUtilsMessageSeverityFlagBitsEXT,
    msg_type: vk.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const vk.VkDebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) vk.VkBool32 {
    _ = user_data;
    const severity_str = switch (severity) {
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => "verbose",
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => "info",
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => "warning",
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => "error",
        else => "unknown",
    };

    const type_str = switch (msg_type) {
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT => "general",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT => "validation",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT => "performance",
        vk.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT => "device address",
        else => "unknown",
    };

    const message: [*c]const u8 = if (callback_data) |cb_data| cb_data.pMessage else "NO MESSAGE!";
    std.debug.print("{s}|{s}: {s}\n", .{ severity_str, type_str, message });

    if (severity >= vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        @panic("Unrecoverable vulkan error.");
    }

    return vk.VK_FALSE;
}
