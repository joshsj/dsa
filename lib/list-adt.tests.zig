const std = @import("std");
const testing = std.testing;

const ArrayList = @import("array-list.zig").ArrayList;
const DoublyLinkedList = @import("doubly-linked-list.zig").DoublyLinkedList;

// TODO add an iterator to check list contents
fn run(list: anytype) !void {
    try testing.expectEqual(0, list.len);

    try list.addFirst(1);
    try list.addFirst(2);
    try list.addLast(4);
    try list.addLast(5);

    try testing.expectEqual(4, list.len);

    try list.addAt(2, 3);

    try testing.expectEqual(5, list.len);

    try testing.expectEqual(1, list.removeFirst());
    try testing.expectEqual(5, list.removeLast());
    try testing.expectEqual(3, list.removeAt(1));

    try testing.expectEqual(4, list.getAt(1));
}

test DoublyLinkedList {
    var list = DoublyLinkedList(u8).init(testing.allocator);
    defer list.deinit();

    try run(&list);
}

test ArrayList {
    var list = try ArrayList(u8).init(testing.allocator);
    defer list.deinit();

    try run(&list);
}
