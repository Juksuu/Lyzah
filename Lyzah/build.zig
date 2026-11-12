const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
        .link_system_libs = &.{
            .{ .name = "glfw" },
            .{ .name = "vulkan" },
        },
    });

    const lyzah = b.addModule("Lyzah", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("./src/main.zig"),
        .imports = &.{
            .{ .name = "c", .module = translator.mod },
        },
    });

    const zmath = b.dependency("zmath", .{});
    lyzah.addImport("zmath", zmath.module("root"));

    const zstbi = b.dependency("zstbi", .{});
    lyzah.addImport("zstbi", zstbi.module("root"));
}
