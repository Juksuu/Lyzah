const std = @import("std");
const lyzah = @import("lyzah");

pub fn main() !void {
    std.debug.print("{}", .{lyzah.add(2, 4)});
    lyzah.another.another();
}
