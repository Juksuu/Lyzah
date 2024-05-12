const std = @import("std");
const c = @import("../c.zig");

pub fn getRequiredInstanceExtensions() [][*:0]const u8 {
    var count: u32 = undefined;
    const extensions = c.glfwGetRequiredInstanceExtensions(&count);
    return @as([*][*:0]const u8, @ptrCast(extensions))[0..count];
}

pub fn errorCallback(code: c_int, description: [*c]const u8) callconv(.C) void {
    std.log.err("Glfw error: {d} {s}", .{ code, description });
}
