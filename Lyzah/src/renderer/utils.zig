const std = @import("std");
const c = @import("../c.zig").libs;

const Allocator = std.mem.Allocator;

pub fn checkSuccess(result: c.VkResult) !void {
    switch (result) {
        c.VK_SUCCESS => {},
        else => return error.VulkanUnexpectedError,
    }
}

pub fn checkValidationLayerSupport(allocator: Allocator, layers: [][*:0]const u8) !bool {
    var layer_count: u32 = undefined;
    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layer_count, null));

    const available_layers = try allocator.alloc(c.VkLayerProperties, layer_count);
    defer allocator.free(available_layers);

    try checkSuccess(c.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr));

    for (layers) |layer_name| {
        var layer_found = false;

        for (available_layers) |layer_properties| {
            const layer_name_with_length = std.mem.span(layer_name);
            const length = @min(layer_name_with_length.len, layer_properties.layerName.len);
            if (std.mem.eql(u8, layer_name_with_length, layer_properties.layerName[0..length])) {
                layer_found = true;
                break;
            }
        }

        if (!layer_found) {
            return false;
        }
    }

    return true;
}

pub fn checkDeviceExtensionSupport(allocator: Allocator, device: c.VkPhysicalDevice, extensions: [][*:0]const u8) !bool {
    var extension_count: u32 = undefined;
    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null));

    const available_extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
    defer allocator.free(available_extensions);

    try checkSuccess(c.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, available_extensions.ptr));

    for (extensions) |name| {
        var found = false;

        for (available_extensions) |extension| {
            const extension_name_with_length = std.mem.span(name);
            const length = @min(extension_name_with_length.len, extension.extensionName.len);
            if (std.mem.eql(u8, extension_name_with_length, extension.extensionName[0..length])) {
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
) callconv(.c) c.VkBool32 {
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

pub fn readFileToBuffer(allocator: Allocator, file_path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);

    _ = try file.read(buffer);

    return buffer;
}

pub fn createShaderModule(code: []const u8, device: c.VkDevice) !c.VkShaderModule {
    const create_info: c.VkShaderModuleCreateInfo = .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @ptrCast(@alignCast(code.ptr)),
    };

    var shader_module: c.VkShaderModule = undefined;
    try checkSuccess(c.vkCreateShaderModule(device, &create_info, null, &shader_module));

    return shader_module;
}

pub fn inSlice(comptime T: type, haystack: []T, needle: T) bool {
    for (haystack) |elem| {
        if (needle == elem) {
            return true;
        }
    }

    return false;
}

pub fn findSupportedFormat(physical_device: c.VkPhysicalDevice, candidates: []c.VkFormat, tiling: c.VkImageTiling, features: c.VkFormatFeatureFlags) !c.VkFormat {
    for (candidates) |format| {
        var props: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(physical_device, format, &props);

        if (tiling == c.VK_IMAGE_TILING_LINEAR and (props.linearTilingFeatures & features) == features) {
            return format;
        } else if (tiling == c.VK_IMAGE_TILING_OPTIMAL and (props.optimalTilingFeatures & features) == features) {
            return format;
        }
    }

    return error.NoSupportedFormat;
}

pub fn findDepthFormat(physical_device: c.VkPhysicalDevice) !c.VkFormat {
    var candidates = [_]c.VkFormat{ c.VK_FORMAT_D32_SFLOAT, c.VK_FORMAT_D32_SFLOAT_S8_UINT, c.VK_FORMAT_D24_UNORM_S8_UINT };
    return findSupportedFormat(
        physical_device,
        &candidates,
        c.VK_IMAGE_TILING_OPTIMAL,
        c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
    );
}

pub fn hasStencilComponent(format: c.VkFormat) !bool {
    return format == c.VK_FORMAT_D32_SFLOAT_S8_UINT or format == c.VK_FORMAT_D24_UNORM_S8_UINT;
}

pub const ObjLineData = union(enum) {
    Vertex: [3]f32,
    TexCoord: [2]f32,
    Face: []ObjFace,
    NotImplemented,
};

pub const ObjFace = struct {
    vertex_index: i32,
    tex_coord_index: i32,
};

pub fn parseObjLine(allocator: Allocator, line: []u8) !ObjLineData {
    var token_iter = std.mem.tokenizeAny(u8, line, " ");
    const line_type = token_iter.next().?;

    if (std.mem.eql(u8, line_type, "v")) {
        return ObjLineData{
            .Vertex = .{
                try std.fmt.parseFloat(f32, token_iter.next().?),
                try std.fmt.parseFloat(f32, token_iter.next().?),
                try std.fmt.parseFloat(f32, token_iter.next().?),
            },
        };
    } else if (std.mem.eql(u8, line_type, "vt")) {
        return ObjLineData{
            .TexCoord = .{
                try std.fmt.parseFloat(f32, token_iter.next().?),
                try std.fmt.parseFloat(f32, token_iter.next().?),
            },
        };
    } else if (std.mem.eql(u8, line_type, "f")) {
        var faces: std.ArrayList(ObjFace) = .empty;

        while (token_iter.next()) |face| {
            var face_iter = std.mem.splitAny(u8, face, "/");
            try faces.append(allocator, .{
                .vertex_index = try std.fmt.parseInt(i32, face_iter.next().?, 10),
                .tex_coord_index = try std.fmt.parseInt(i32, face_iter.next().?, 10),
            });
        }

        return ObjLineData{
            .Face = try faces.toOwnedSlice(allocator),
        };
    } else {
        return ObjLineData.NotImplemented;
    }
}
