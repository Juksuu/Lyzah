const std = @import("std");

pub fn build(b: *std.Build) void {
    const lyzah = b.addModule("Lyzah", .{
        .root_source_file = b.path("./src/lyzah.zig"),
    });

    const zmath = b.dependency("zmath", .{});
    lyzah.addImport("zmath", zmath.module("root"));

    const zstbi = b.dependency("zstbi", .{});
    lyzah.addImport("zstbi", zstbi.module("root"));
    lyzah.linkLibrary(zstbi.artifact("zstbi"));
}
