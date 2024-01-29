const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // C libraries
    const vulkan_module = b.createModule(.{
        .root_source_file = .{ .path = "lib/vulkan.zig" },
    });
    const glfw_module = b.createModule(.{
        .root_source_file = .{ .path = "lib/glfw.zig" },
    });

    // Lyzah modules
    const window_module = b.createModule(.{
        .root_source_file = .{ .path = "src/window/main.zig" },
        .imports = &.{
            .{ .name = "glfw", .module = glfw_module },
        },
    });

    const renderer_module = b.createModule(.{
        .root_source_file = .{ .path = "src/renderer/main.zig" },
        .imports = &.{
            .{ .name = "vulkan", .module = vulkan_module },
        },
    });

    _ = b.addModule("lyzah", .{
        .root_source_file = .{ .path = "src/main.zig" },
        .imports = &.{
            .{ .name = "window", .module = window_module },
            .{ .name = "renderer", .module = renderer_module },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "Lyzah",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/main.zig" },
    });

    lib.linkLibC();
    lib.linkSystemLibrary("glfw");
    lib.linkSystemLibrary("vulkan");

    b.installArtifact(lib);
}
