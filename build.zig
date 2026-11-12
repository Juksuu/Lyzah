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

    // Sandbox build
    const sb_exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("sandbox/src/main.zig"),
        .imports = &.{
            .{ .name = "Lyzah", .module = lyzah },
        },
    });

    const sb_exe = b.addExecutable(.{
        .name = "sandbox",
        .root_module = sb_exe_mod,
    });

    b.installArtifact(sb_exe);

    const shader_step = b.step("shaders", "Compile shaders");

    try addShader(b, shader_step, "sandbox/shaders/shader.vert", "sandbox/shaders/vert.spv");
    try addShader(b, shader_step, "sandbox/shaders/shader.frag", "sandbox/shaders/frag.spv");

    const run_cmd = b.addRunArtifact(sb_exe);
    run_cmd.step.dependOn(shader_step);
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ZLS check for diagnostic errors
    const sb_exe_check = b.addExecutable(.{
        .name = "sanbox_check",
        .root_module = sb_exe_mod,
    });

    const sb_check = b.step("check", "Check if sanbox compiles");
    sb_check.dependOn(&sb_exe_check.step);
}

fn addShader(b: *std.Build, shader_step: *std.Build.Step, in_file: []const u8, out_file: []const u8) !void {
    // example: glslc shaders/shader.vert -o shaders/shader.vert

    const shader_cmd = b.addSystemCommand(&[_][]const u8{ "glslc", in_file, "-o", out_file });
    shader_cmd.step.dependOn(b.getInstallStep());

    shader_step.dependOn(&shader_cmd.step);
}
