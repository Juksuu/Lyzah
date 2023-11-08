pub const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

pub const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
