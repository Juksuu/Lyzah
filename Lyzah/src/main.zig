const std = @import("std");
pub const another = @import("another.zig");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}
