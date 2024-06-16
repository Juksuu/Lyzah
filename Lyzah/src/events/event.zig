pub const WindowResizeEvent = struct {
    width: u32,
    height: u32,
};

pub const Event = union(enum) {
    window_resize: WindowResizeEvent,
};

