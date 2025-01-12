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
            const node = try self.createNode(&value);

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
        pub fn addLast(self: *Self, value: T) Allocator.Error!void {
            const node = try self.createNode(&value);

            if (self.tail) |tail| {
                node.prev = tail;
                tail.next = node;
            } else {
                self.head = node;
            }

            self.tail = node;
            self.len += 1;
        }

        /// O(n)
        pub fn addAt(self: *Self, index: usize, value: T) Allocator.Error!void {
            if (index == 0) {
                return self.addFirst(value);
            }

            if (index == self.len) {
                return self.addLast(value);
            }

            if (index > self.len) {
                // TODO OOB error
                return;
            }

            const curr = self.getNodeAt(index).?;
            const new = try self.createNode(&value);

            new.prev = curr.prev;
            new.next = curr;

            if (curr.prev) |curr_prev| {
                curr_prev.next = new;
            }

            curr.prev = new;

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

        /// O(1)
        pub fn removeLast(self: *Self) ?T {
            if (self.tail) |tail| {
                self.len -= 1;

                if (tail.prev) |new_tail| {
                    new_tail.next = null;
                    self.tail = new_tail;
                } else {
                    self.head = null;
                    self.tail = null;
                }

                defer self.allocator.destroy(tail);
                return tail.value;
            } else {
                return null;
            }
        }

        /// O(n)
        pub fn removeAt(self: *Self, index: usize) ?T {
            if (index >= self.len) {
                return null;
            }

            if (index == 0) {
                return self.removeFirst();
            }

            if (index == self.len - 1) {
                return self.removeLast();
            }

            const node = self.getNodeAt(index).?;

            node.prev.?.next = node.next;
            node.next.?.prev = node.prev;

            self.len -= 1;

            defer self.allocator.destroy(node);
            return node.value;
        }

        /// O(n)
        pub fn getAt(self: Self, index: usize) ?T {
            // Cool stuff
            return if (self.getNodeAt(index)) |node| node.value else null;
        }

        fn getNodeAt(self: Self, index: usize) ?*Node {
            // TODO OOB error
            if (index >= self.len) {
                return null;
            }

            var curr = self.head.?;

            for (0..index) |_| {
                curr = curr.next.?;
            }

            return curr;
        }

        /// O(n)
        pub fn clear(self: *Self) void {
            while (self.len != 0) {
                _ = self.removeFirst();
            }
        }

        fn createNode(self: Self, value: *const T) Allocator.Error!*Node {
            const node = try self.allocator.create(Node);

            node.value = value.*;
            node.next = null;
            node.prev = null;

            return node;
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

test "addFirst() should create the head and tail when empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expect(list.head != null);
    try testing.expectEqual(list.head, list.tail);

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);
    try testing.expectEqual(null, list.head.?.prev);

    try testing.expectEqual(1, list.len);
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

    try testing.expectEqual(2, list.len);
}

test "addLast() should create the head and tail when empty" {
    var list = create();
    defer list.deinit();

    try list.addLast(10);

    try testing.expect(list.head != null);
    try testing.expectEqual(list.head, list.tail);

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);
    try testing.expectEqual(null, list.head.?.prev);

    try testing.expectEqual(1, list.len);
}

test "addLast() should create a new tail only when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addLast(11);

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(11, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "addAt(0) should create the head and tail when empty" {
    var list = create();
    defer list.deinit();

    try list.addAt(0, 10);

    try testing.expect(list.head != null);
    try testing.expectEqual(list.head, list.tail);

    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(null, list.head.?.next);
    try testing.expectEqual(null, list.head.?.prev);

    try testing.expectEqual(1, list.len);
}

test "addAt(0) should create a new head only when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addAt(0, 11);

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(10, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "addAt(len - 1) should create a new tail only when not empty" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addAt(1, 11);

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(10, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(11, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "addAt(middle) should insert a new node at the specified index" {
    var list = create();
    defer list.deinit();

    try list.addLast(10);
    try list.addLast(12);
    try list.addLast(13);

    try list.addAt(1, 11);

    try testing.expect(list.head != null);

    const ten = list.head.?;

    try testing.expectEqual(null, ten.prev);
    try testing.expectEqual(10, ten.value);
    try testing.expect(null != ten.next);

    const eleven = ten.next.?;

    try testing.expectEqual(ten, eleven.prev);
    try testing.expectEqual(11, eleven.value);
    try testing.expect(null != eleven.next);

    const twelve = eleven.next.?;

    try testing.expectEqual(eleven, twelve.prev);
    try testing.expectEqual(12, twelve.value);
    try testing.expect(null != twelve.next);

    const thirteen = twelve.next.?;

    try testing.expectEqual(twelve, thirteen.prev);
    try testing.expectEqual(13, thirteen.value);
    try testing.expectEqual(null, thirteen.next);

    try testing.expectEqual(thirteen, list.tail);

    try testing.expectEqual(4, list.len);
}

test "removeFirst() should return null when empty" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.removeFirst());
}

test "removeFirst() should remove the head and tail when no items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.removeFirst());

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);

    try testing.expectEqual(0, list.len);
}

test "removeFirst() should move the head when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    try list.addFirst(12);
    
    try testing.expectEqual(12, list.removeFirst());

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(10, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "removeLast() should return null when empty" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.removeLast());
}

test "removeLast() should remove the head and tail when no items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.removeLast());

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);

    try testing.expectEqual(0, list.len);
}

test "removeLast() should move the tail when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    try list.addFirst(12);
    
    try testing.expectEqual(10, list.removeLast());

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(12, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(11, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "removeAt() should return null when index is invalid" {
    var list = create();
    defer list.deinit();

    try testing.expectEqual(null, list.removeAt(0));
}

test "removeAt(0) should remove the head and tail when no items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.removeAt(0));

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);

    try testing.expectEqual(0, list.len);
}

test "removeAt(0) should move the head when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    try list.addFirst(12);
    
    try testing.expectEqual(12, list.removeAt(0));

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(11, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(10, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "removeAt() should remove the head and tail when no items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);

    try testing.expectEqual(10, list.removeAt(0));

    try testing.expectEqual(null, list.head);
    try testing.expectEqual(null, list.tail);

    try testing.expectEqual(0, list.len);
}

test "removeAt() should move the tail when items remain" {
    var list = create();
    defer list.deinit();

    try list.addFirst(10);
    try list.addFirst(11);
    try list.addFirst(12);
    
    try testing.expectEqual(10, list.removeAt(2));

    try testing.expect(list.head != null);
    try testing.expect(list.tail != null);

    try testing.expectEqual(null, list.head.?.prev);
    try testing.expectEqual(12, list.head.?.value);
    try testing.expectEqual(list.tail, list.head.?.next);

    try testing.expectEqual(list.head, list.tail.?.prev);
    try testing.expectEqual(11, list.tail.?.value);
    try testing.expectEqual(null, list.tail.?.next);

    try testing.expectEqual(2, list.len);
}

test "removeAt(middle) should remove the node at the specified index" {
    var list = create();
    defer list.deinit();

    try list.addLast(10);
    try list.addLast(11);
    try list.addLast(12);

    try testing.expectEqual(11, list.removeAt(1));

    try testing.expect(list.head != null);

    const ten = list.head.?;

    try testing.expectEqual(null, ten.prev);
    try testing.expectEqual(10, ten.value);
    try testing.expect(null != ten.next);

    const twelve = ten.next.?;

    try testing.expectEqual(ten, twelve.prev);
    try testing.expectEqual(12, twelve.value);
    try testing.expectEqual(null, twelve.next);

    try testing.expectEqual(twelve, list.tail);

    try testing.expectEqual(2, list.len);
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
    try testing.expectEqual(null, list.tail);
}

