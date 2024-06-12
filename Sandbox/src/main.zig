const std = @import("std");
const lyzah = @import("lyzah");

pub fn main() !void {
    var application = try lyzah.Application.init();
    defer application.destroy();

    try application.run();
}
