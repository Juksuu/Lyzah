const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lib = b.addStaticLibrary(.{
        .name = "Lyzah",
        .target = target,
        .optimize = optimize,
    });

    // C libraries
    const vulkan_module = b.addModule("vulkan", .{
        .source_file = .{ .path = "lib/vulkan.zig" },
    });
    const glfw_module = b.addModule("glfw", .{
        .source_file = .{ .path = "lib/glfw.zig" },
    });

    // Lyzah modules
    const window_module = b.addModule("window", .{
        .source_file = .{ .path = "src/window/main.zig" },
        .dependencies = &.{
            .{ .name = "glfw", .module = glfw_module },
        },
    });

    lib.addModule(
        "lyzah",
        b.addModule("lyzah", .{
            .source_file = .{ .path = "src/main.zig" },
            .dependencies = &.{
                // C libraries
                .{ .name = "vulkan", .module = vulkan_module },
                .{ .name = "glfw", .module = glfw_module },

                // Lyzah modules
                .{ .name = "window", .module = window_module },
            },
        }),
    );

    lib.linkLibC();
    lib.linkSystemLibrary("glfw");
    lib.linkSystemLibrary("vulkan");

    b.installArtifact(lib);
}
