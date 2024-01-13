const std = @import("std");
const vk = @import("vulkan");

pub inline fn checkSuccess(result: vk.VkResult) !void {
    switch (result) {
        vk.VK_SUCCESS => {},
        else => return error.VulkanUnexpectedError,
    }
}

pub inline fn checkValidationLayerSupport(allocator: *std.mem.Allocator, layers: [][*:0]const u8) !bool {
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
