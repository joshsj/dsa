const testing = @import("./testing.zig");

const SinglyLinkedList = @import("singly-linked-list.zig").SinglyLinkedList;

pub fn SinglyLinkedListIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = SinglyLinkedList(T).Node;

        node: ?*const Node,
        moved: bool = false,

        pub fn init(list: SinglyLinkedList(T)) Self {
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

    var iter = SinglyLinkedListIterator(u8).init(list);
    const expected = [_]u8 { 1, 2, 3, };

    try testing.expectEqualSliceToIter(u8, &expected, &iter);
}

