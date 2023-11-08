const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("lyzah", .{
        .source_file = .{ .path = "src/main.zig" },
    });

    var lib = b.addStaticLibrary(.{
        .name = "Lyzah",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkSystemLibrary("glfw");
    lib.linkSystemLibrary("vulkan");

    b.installArtifact(lib);
}
