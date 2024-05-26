const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("lyzah", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        } },
    });
}
