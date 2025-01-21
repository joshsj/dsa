const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const DoublyLinkedList = @import("./doubly-linked-list.zig").DoublyLinkedList;

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        items: DoublyLinkedList(T),

        pub fn init(allocator: Allocator) Self {
            return Self { .items = DoublyLinkedList(T).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        /// O(1)
        pub fn enqueue(self: *Self, value: T) Allocator.Error!void {
            try self.items.addFirst(value);
        }

        /// O(1)
        pub fn deque(self: *Self) ?T {
            return self.items.removeLast();
        }

        /// O(1)
        pub fn peek(self: Self) ?T {
            return if (self.items.tail) |tail| tail.value else null;
        }
    };
}

test Queue {
    var queue = Queue(u8).init(testing.allocator);
    defer queue.deinit();

    // TODO: imporove once DLL has an iterator
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    try testing.expectEqual(1, queue.deque());
    try testing.expectEqual(2, queue.deque());
    try testing.expectEqual(3, queue.deque());
}
