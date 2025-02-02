const std = @import("std");

const testing = @import("testing.zig");
const DoublyLinkedList = @import("doubly-linked-list.zig").DoublyLinkedList;
const ArrayList = @import("array-list.zig").ArrayList;

// TODO: backwards?
pub fn DoublyLinkedListIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = DoublyLinkedList(T).Node;

        node: ?*const Node,
        moved: bool = false,

        pub fn init(list: DoublyLinkedList(T)) Self {
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

test DoublyLinkedList {
    var list = DoublyLinkedList(u8).init(testing.allocator);
    defer list.deinit();

    try list.addFirst(3);
    try list.addFirst(2);
    try list.addFirst(1);

    var iter = DoublyLinkedListIterator(u8).init(list);
    const expected = [_]u8 { 1, 2, 3, };

    try testing.expectEqualSliceToIter(u8, &expected, &iter);
}
