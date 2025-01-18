const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn BinaryNode(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        left: ?*Self = null,
        right: ?*Self = null,
    };
}

