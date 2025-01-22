const std = @import("std");
const testing = std.testing;

const SinglyLinkedList = @import("../../structures/singly-linked-list.zig").SinglyLinkedList;
const DoublyLinkedList = @import("../../structures/doubly-linked-list.zig").DoublyLinkedList;
const ArrayList = @import("../../structures/array-list.zig").ArrayList;

pub fn SinglyLinkedListIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = SinglyLinkedList(T).Node;

        node: ?*const Node,
        moved: bool = false,

        pub fn new(list: SinglyLinkedList(T)) Self {
            return Self { .node = list.head };
        }

        pub fn curr(self: Self) ?T {
            return if (self.moved and self.node != null) self.node.?.value else null;
        }

        pub fn next(self: *Self) !?T {
            if (self.moved) {
                self.node = if (self.node) |c| c.next else null;
            } else {
                self.moved = true;
            }

            return self.curr();
        }
    };
}

// TODO backwards?
pub fn DoublyLinkedListIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = DoublyLinkedList(T).Node;

        node: ?*const Node,
        moved: bool = false,

        pub fn new(list: DoublyLinkedList(T)) Self {
            return Self { .node = list.head };
        }

        pub fn curr(self: Self) ?T {
            return if (self.moved and self.node != null) self.node.?.value else null;
        }

        pub fn next(self: *Self) !?T {
            if (self.moved) {
                self.node = if (self.node) |c| c.next else null;
            } else {
                self.moved = true;
            }

            return self.curr();
        }
    };
}

test SinglyLinkedList {
    var list = SinglyLinkedList(u8).init(testing.allocator);
    defer list.deinit();

    try list.addFirst(3);
    try list.addFirst(2);
    try list.addFirst(1);

    var iter = SinglyLinkedListIterator(u8).new(list);

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 1, 2, 3, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
}

test DoublyLinkedList {
    var list = DoublyLinkedList(u8).init(testing.allocator);
    defer list.deinit();

    try list.addFirst(3);
    try list.addFirst(2);
    try list.addFirst(1);

    var iter = DoublyLinkedListIterator(u8).new(list);

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 1, 2, 3, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
}
