const std = @import("std");
const path = std.fs.path;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Sandbox",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/main.zig"),
        }),
    });

    const lyzah_dep = b.dependency("Lyzah", .{});

    exe.root_module.addImport("Lyzah", lyzah_dep.module("Lyzah"));
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");

    b.installArtifact(exe);

    const shader_step = b.step("shaders", "Compile shaders");

    try addShader(b, shader_step, "shaders/shader.vert", "shaders/vert.spv");
    try addShader(b, shader_step, "shaders/shader.frag", "shaders/frag.spv");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(shader_step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addShader(b: *std.Build, shader_step: *std.Build.Step, in_file: []const u8, out_file: []const u8) !void {
    // example: glslc shaders/shader.vert -o shaders/shader.vert

    const shader_cmd = b.addSystemCommand(&[_][]const u8{ "glslc", in_file, "-o", out_file });
    shader_cmd.step.dependOn(b.getInstallStep());

    shader_step.dependOn(&shader_cmd.step);
}
