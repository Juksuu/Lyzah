const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lib = b.addStaticLibrary(.{
        .name = "Lyzah",
        .target = target,
        .optimize = optimize,
    });

    const vulkan_module = b.addModule("vulkan", .{
        .source_file = .{ .path = "lib/vulkan.zig" },
    });
    const glfw_module = b.addModule("glfw", .{
        .source_file = .{ .path = "lib/glfw.zig" },
    });

    lib.addModule(
        "lyzah",
        b.addModule("lyzah", .{
            .source_file = .{ .path = "src/main.zig" },
            .dependencies = &.{
                .{ .name = "vulkan", .module = vulkan_module },
                .{ .name = "glfw", .module = glfw_module },
            },
        }),
    );

    lib.linkLibC();
    lib.linkSystemLibrary("glfw");
    lib.linkSystemLibrary("vulkan");

    b.installArtifact(lib);
}
