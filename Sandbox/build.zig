const std = @import("std");
const path = std.fs.path;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Sandbox",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        } },
    });

    const lyzah_dep = b.dependency("lyzah", .{});

    exe.root_module.addImport("lyzah", lyzah_dep.module("lyzah"));
    exe.linkLibC();
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("vulkan");

    b.installArtifact(exe);

    const shader_step = b.step("shaders", "Compile shaders");

    try addShader(b, shader_step, "shader.vert", "vert.spv");
    try addShader(b, shader_step, "shader.frag", "frag.spv");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(shader_step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addShader(b: *std.Build, shaderStep: *std.Build.Step, inFile: []const u8, outFile: []const u8) !void {
    // example: glslc shaders/shader.vert -o shaders/shader.vert

    const dirname = "shaders";
    const inPath = try path.join(b.allocator, &[_][]const u8{ dirname, inFile });
    const outPath = try path.join(b.allocator, &[_][]const u8{ dirname, outFile });

    const runCmd = b.addSystemCommand(&[_][]const u8{ "glslc", inPath, "-o", outPath });
    runCmd.step.dependOn(b.getInstallStep());

    shaderStep.dependOn(&runCmd.step);
}
