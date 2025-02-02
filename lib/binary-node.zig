const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn BinaryNode(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const DepthFirstIterator = @import("binary-node.iterator.zig").DepthFirstIterator(T);
        pub const BreadthFirstIterator = @import("binary-node.iterator.zig").BreadthFirstIterator(T);

        value: T,
        left: ?*Self = null,
        right: ?*Self = null,

        pub fn depthFirstIterator(
            self: *const Self,
            allocator: Allocator,
            order: DepthFirstIterator.Order
        ) DepthFirstIterator {
            return switch (order) {
                .pre => DepthFirstIterator.init(allocator, self, .pre),
                .in => DepthFirstIterator.init(allocator, self, .in),
                .post => DepthFirstIterator.init(allocator, self, .post),
            };
        }

        pub fn breadthFirstIterator(self: *const Self, allocator: Allocator) BreadthFirstIterator {
            return BreadthFirstIterator.init(allocator, self);
        }
    };
}

