const std = @import("std");
const Allocator = std.mem.Allocator;

const Event = @import("event.zig").Event;

const EventDispatcher = @This();

const EventListener = struct {
    ptr: *anyopaque,
    func: *const fn (ptr: *anyopaque, event: Event) void,
};

var event_listeners: std.ArrayList(EventListener) = undefined;

pub fn init(allocator: Allocator) void {
    event_listeners = std.ArrayList(EventListener).init(allocator);
}

pub fn destroy() void {
    event_listeners.deinit();
}

pub fn addEventListener(listener: EventListener) !void {
    try event_listeners.append(listener);
}

pub fn onEvent(event: Event) void {
    for (event_listeners.items) |listener| {
        listener.func(listener.ptr, event);
    }
}
