const std = @import("std");

pub fn build(b: *std.Build) void {
    const lyzah = b.addModule("Lyzah", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/lyzah.zig",
        } },
    });

    const zmath = b.dependency("zmath", .{});
    lyzah.addImport("zmath", zmath.module("root"));
}
