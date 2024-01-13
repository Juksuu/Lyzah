const glfw = @import("glfw");

pub inline fn getRequiredInstanceExtensions() [][*:0]const u8 {
    var count: u32 = undefined;
    const extensions = glfw.glfwGetRequiredInstanceExtensions(&count);
    return @as([*][*:0]const u8, @ptrCast(extensions))[0..count];
}
