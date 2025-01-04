const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn DoublyLinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        const Node = struct {
            value: T,
            next: ?*Node,
            prev: ?*Node,
        };

        allocator: Allocator,
        len: usize,
        head: ?*Node,
        tail: ?*Node,

        pub fn init(allocator: Allocator) Self {
            return Self { 
                .len = 0,
                .head = null,
                .tail = null,
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
            node.next = null;
            node.prev = null;

            if (self.head) |head| {
                node.next = head;
                head.prev = node;
            } else {
                self.tail = node;
            }

            self.head = node;
            self.len += 1;
        }

        /// O(1)
        pub fn removeFirst(self: *Self) ?T {
            if (self.head) |head| {
                self.len -= 1;

                if (head.next) |new_head| {
                    new_head.prev = null;
                    self.head = new_head;
                } else {
                    self.head = null;
                    self.tail = null;
                }

                defer self.allocator.destroy(head);
                return head.value;
            } 

            return null;
        }

        /// O(n)
        pub fn clear(self: *Self) void {
            while (!self.isEmpty()) {
                _ = self.removeFirst();
            }
        }

        /// O(1)
        pub fn isEmpty(self: Self) bool {
            return self.len == 0;
        }
    };
}

fn create() DoublyLinkedList(u8) {
    return DoublyLinkedList(u8).init(testing.allocator);
}

test "len should be 0 when no items added" {
    const list = create();

    try testing.expectEqual(0, list.len);
}

test "head should be null when no items added" {
    const list = create();

    try testing.expectEqual(null, list.head);
}

test "tail should be null when no items added" {
    const list = create();

    try testing.expectEqual(null, list.tail);
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

test "addFirst() should increment len" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(1, list.len);
}

test "addFirst() should create the head and tail when empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expect(list.head != null);
    try testing.expectEqual(list.head, list.tail);

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);
    try testing.expectEqual(null, list.head.?.prev);
}

test "addFirst() should create a new head only when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(10, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);
}

test "removeFirst() should return null when empty" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.removeFirst());
}

test "removeFirst() should return the value at the head when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    try testing.expectEqual(11, list.removeFirst());
}

test "removeFirst() should remove the head only when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    try list.addFirst(12);
    _ = list.removeFirst();

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(10, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);
}

test "removeFirst() should remove the head and tail when emptied" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    _ = list.removeFirst();
    _ = list.removeFirst();

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);
}

test "removeFirst() should decrement len when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    _ = list.removeFirst();

    try testing.expectEqual(1, list.len);
}

test "clear() should remove all items" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);

    list.clear();

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);
}

