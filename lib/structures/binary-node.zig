const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const DepthFirstIterator = @import("../algorithms/tree/iterator.zig").DepthFirstIterator;
const BreadthFirstIterator = @import("../algorithms/tree/iterator.zig").BreadthFirstIterator;

pub fn BinaryNode(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        left: ?*Self = null,
        right: ?*Self = null,

        pub fn depthFirstIterator(
            self: *const Self,
            allocator: Allocator,
            order: DepthFirstIterator(T).Order
        ) DepthFirstIterator(T) {
            return switch (order) {
                .pre => DepthFirstIterator(T).init(allocator, self, .pre),
                .in => DepthFirstIterator(T).init(allocator, self, .in),
                .post => DepthFirstIterator(T).init(allocator, self, .post),
            };
        }

        pub fn breadthFirstIterator(self: *const Self, allocator: Allocator) BreadthFirstIterator(T) {
            return BreadthFirstIterator(T).init(allocator, self);
        }
    };
}

