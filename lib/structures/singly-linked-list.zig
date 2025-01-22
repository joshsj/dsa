const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const SinglyLinkedListIterator = @import("../algorithms/linked/iterator.zig").SinglyLinkedListIterator;

pub fn SinglyLinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

       pub const Node = struct {
            value: T,
            next: ?*Node,
        };

        allocator: Allocator,
        len: usize,
        head: ?*Node,

        pub fn init(allocator: Allocator) Self {
            return Self { 
                .len = 0,
                .head = null,
                .allocator = allocator
            };
        }

        pub fn deinit(self: *Self) void {
            self.clear();
        }

        /// O(1)
        pub fn addFirst(self: *Self, value: T) Allocator.Error!void {
            const node = try self.allocator.create(Node);

            node.value = value;
            node.next = self.head;

            self.head = node;
            self.len += 1;
        }

        /// O(1)
        pub fn removeFirst(self: *Self) ?T {
            if (self.head) |node| {
                defer self.allocator.destroy(node);

                self.head = node.next;
                self.len -= 1;

                return node.value;
            } else {
                return null;
            }
        }

        /// O(n)
        pub fn getAt(self: Self, index: usize) ?T {
            // Cool stuff
            return if (self.getNodeAt(index)) |node| node.value else null;
        }

        fn getNodeAt(self: Self, index: usize) ?*Node {
            if (index >= self.len) {
                return null;
            }

            var curr = self.head orelse unreachable;

            for (0..index) |_| {
                curr = curr.next orelse unreachable;
            }

            return curr;
        }

        pub fn iterator(self: Self) SinglyLinkedListIterator(T) {
            return SinglyLinkedListIterator(T).new(self);
        }

        /// O(n)
        pub fn clear(self: *Self) void {
            while (self.len != 0) {
                _ = self.removeFirst();
            }
        }

        /// O(1)
        pub fn isEmpty(self: Self) bool {
            return self.len == 0;
        }
    };
}

fn create() SinglyLinkedList(u8) {
    return SinglyLinkedList(u8).init(testing.allocator);
}

test "len should be 0 when no items added" {
    const list = create();

    try testing.expectEqual(0, list.len);
}

test "head should be null when no items added" {
    const list = create();

    try testing.expectEqual(null, list.head);
}

test "isEmpty() should be true when no items added" {
    const list = create();

    try testing.expect(list.isEmpty());
}

test "isEmpty() should be false when no items added" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expect(!list.isEmpty());
}

test "addFirst() should create the head when empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);

    try testing.expectEqual(1, list.len);
}

test "addFirst() should create a new head when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(10, list.head.?.next.?.value);
    try testing.expectEqual(null, list.head.?.next.?.next);

    try testing.expectEqual(2, list.len);
}

test "removeFirst() should return null when empty" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.removeFirst());
}

test "removeFirst() should remove the head when no items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.removeFirst());

    try testing.expectEqual(null, list.head);

    try testing.expectEqual(0, list.len);
}

test "removeFirst() should move the head when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    try testing.expectEqual(11, list.removeFirst());

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);

    try testing.expectEqual(1, list.len);
}

test "getAt() should return the value of the node at the specified index" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    try testing.expectEqual(11, list.getAt(0));
    try testing.expectEqual(10, list.getAt(1));
}

test "getAt() should return null when the node does not exist" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.getAt(0));
}

test "clear() should remove all items" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    list.clear();

    try testing.expectEqual(null, list.head);
}

