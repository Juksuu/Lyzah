const std = @import("std");
const Application = @import("Lyzah").Application;

pub fn main() !void {
    var application = try Application.init();
    defer application.destroy();

    try application.run();
}
