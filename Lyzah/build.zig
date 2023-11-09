const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lib = b.addStaticLibrary(.{
        .name = "Lyzah",
        .target = target,
        .optimize = optimize,
    });

    const c_lib_module = b.addModule("c_lib", .{
        .source_file = .{ .path = "lib/c_lib.zig" },
    });

    lib.addModule(
        "lyzah",
        b.addModule("lyzah", .{
            .source_file = .{ .path = "src/main.zig" },
            .dependencies = &.{
                .{ .name = "c_lib", .module = c_lib_module },
            },
        }),
    );

    lib.linkLibC();
    lib.linkSystemLibrary("glfw");
    lib.linkSystemLibrary("vulkan");

    b.installArtifact(lib);
}
