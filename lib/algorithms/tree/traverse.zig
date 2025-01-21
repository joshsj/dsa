const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const BinaryNode = @import("../../structures/binary-node.zig").BinaryNode;
const Queue = @import("../../structures/queue.zig").Queue;
const Stack = @import("../../structures/stack.zig").Stack;

pub fn GoingNode(comptime T: type) type {
    return struct {
        const Self = @This();

        const Direction = enum { left, self, right };

        inner: *const BinaryNode(T),
        going: ?Direction = null,

        fn new(allocator: Allocator, inner: *const BinaryNode(T)) Allocator.Error!*Self {
            var self = try allocator.create(Self);
            self.inner = inner;
            self.going = null;
            return self;
        }
    };
}

/// O(n)
pub fn DepthFirstIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Order = enum { pre, in, post };

        allocator: Allocator,
        path: Stack(*GoingNode(T)),
        root: *const BinaryNode(u8),
        move: *const fn(*Self) Allocator.Error!void,
        moved: bool = false,

        pub fn init(
            allocator: Allocator, 
            root: *const BinaryNode(u8),
            order: Order
        ) Self {
            return Self { 
                .allocator = allocator,
                .path = Stack(*GoingNode(T)).init(allocator), 
                .root = root,
                .move = switch (order) {
                    .pre => &movePreOrder,
                    .in => &moveInOrder,
                    .post => &movePostOrder,
                }
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.path.pop()) |node| {
                self.allocator.destroy(node);
            }

            self.path.deinit();
        }
        
        pub fn curr(self: Self) ?T {
            return if (self.moved and self.path.peek() != null) self.path.peek().?.inner.value else null;
        }

        pub fn next(self: *Self) Allocator.Error!?T {
            if (!self.moved) {
                try self.path.push(try GoingNode(T).new(self.allocator, self.root));
                self.moved = true;
            }

            try self.move(self);
            return self.curr();
        }

        fn movePreOrder(self: *Self) Allocator.Error!void {
            const node = self.path.peek() orelse return;

            if (node.going) |going| {
                switch (going) {
                    .self => try goLeft(self, node),
                    .left => try goRight(self, node),
                    .right => try goUp(self, node),
                }
            } else {
                goSelf(node);
            }
        }

        fn moveInOrder(self: *Self) Allocator.Error!void {
            const node = self.path.peek() orelse return;

            if (node.going) |going| {
                switch (going) {
                    .left => goSelf(node),
                    .self => try goRight(self, node),
                    .right => try goUp(self, node),
                }
            } else {
                try goLeft(self, node);
            }
        }

        fn movePostOrder(self: *Self) Allocator.Error!void {
            const node = self.path.peek() orelse return;

            if (node.going) |going| {
                switch (going) {
                    .left => try goRight(self, node),
                    .right => goSelf(node),
                    .self => try goUp(self, node),
                }
            } else {
                try goLeft(self, node);
            }
        }

        fn goLeft(self: *Self, node: *GoingNode(T)) Allocator.Error!void {
            node.going = .left;

            if (node.inner.left) |left| {
                try self.path.push(try GoingNode(T).new(self.allocator, left)); 
            }

            try self.move(self);
        }

        fn goSelf(node: *GoingNode(T)) void {
            node.going = .self;
        }

        fn goRight(self: *Self, node: *GoingNode(T)) Allocator.Error!void {
            node.going = .right;

            if (node.inner.right) |right| {
                try self.path.push(try GoingNode(T).new(self.allocator, right)); 
            }

            try self.move(self);
        }

        fn goUp(self: *Self, node: *GoingNode(T)) Allocator.Error!void {
            _ = self.path.pop();
            self.allocator.destroy(node);

            try self.move(self);
        }
    };
}

/// O(n)
pub fn BreadthFirstIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        queue: Queue(*const BinaryNode(T)),
        root: *const BinaryNode(u8),
        moved: bool = false,

        pub fn init(allocator: Allocator, root: *const BinaryNode(u8),) Self {
            return Self { 
                .allocator = allocator,
                .queue = Queue(*const BinaryNode(T)).init(allocator), 
                .root = root,
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.queue.deque()) |node| {
                self.allocator.destroy(node);
            }

            self.queue.deinit();
        }
        
        pub fn curr(self: Self) ?T {
            return if (self.moved and self.queue.peek() != null) self.queue.peek().?.value else null;
        }

        pub fn next(self: *Self) Allocator.Error!?T {
            if (self.moved) {
                const prev =  self.queue.deque() orelse return null;

                if (prev.left) |left| { try self.queue.enqueue(left); }
                if (prev.right) |right| { try self.queue.enqueue(right); }
            } else {
                try self.queue.enqueue(self.root);

                self.moved = true;
            }

            return self.curr();
        }
    };
}

const TestNode = BinaryNode(u8);

test "pre" {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &manyNodes, .pre);
    defer iter.deinit();

    try testing.expectEqual(null, iter.curr());

    try testing.expectEqual(4, iter.next());
    try testing.expectEqual(4, iter.curr());

    try testing.expectEqual(7, iter.next());
    try testing.expectEqual(7, iter.curr());

    try testing.expectEqual(2, iter.next());
    try testing.expectEqual(2, iter.curr());

    try testing.expectEqual(1, iter.next());
    try testing.expectEqual(1, iter.curr());

    try testing.expectEqual(5, iter.next());
    try testing.expectEqual(5, iter.curr());

    try testing.expectEqual(null, iter.next());
    try testing.expectEqual(null, iter.curr());
}

test "in" {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &manyNodes, .in);
    defer iter.deinit();

    try testing.expectEqual(null, iter.curr());

    try testing.expectEqual(7, iter.next());
    try testing.expectEqual(7, iter.curr());

    try testing.expectEqual(2, iter.next());
    try testing.expectEqual(2, iter.curr());

    try testing.expectEqual(4, iter.next());
    try testing.expectEqual(4, iter.curr());

    try testing.expectEqual(5, iter.next());
    try testing.expectEqual(5, iter.curr());

    try testing.expectEqual(1, iter.next());
    try testing.expectEqual(1, iter.curr());

    try testing.expectEqual(null, iter.next());
    try testing.expectEqual(null, iter.curr());
}

test "post" {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &manyNodes, .post);
    defer iter.deinit();

    try testing.expectEqual(null, iter.curr());

    try testing.expectEqual(2, iter.next());
    try testing.expectEqual(2, iter.curr());

    try testing.expectEqual(7, iter.next());
    try testing.expectEqual(7, iter.curr());

    try testing.expectEqual(5, iter.next());
    try testing.expectEqual(5, iter.curr());

    try testing.expectEqual(1, iter.next());
    try testing.expectEqual(1, iter.curr());

    try testing.expectEqual(4, iter.next());
    try testing.expectEqual(4, iter.curr());

    try testing.expectEqual(null, iter.next());
    try testing.expectEqual(null, iter.curr());
}

test BreadthFirstIterator {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = BreadthFirstIterator(u8).init(testing.allocator, &manyNodes);
    defer iter.deinit();

    try testing.expectEqual(null, iter.curr());

    try testing.expectEqual(4, iter.next());
    try testing.expectEqual(4, iter.curr());

    try testing.expectEqual(7, iter.next());
    try testing.expectEqual(7, iter.curr());

    try testing.expectEqual(1, iter.next());
    try testing.expectEqual(1, iter.curr());

    try testing.expectEqual(2, iter.next());
    try testing.expectEqual(2, iter.curr());

    try testing.expectEqual(5, iter.next());
    try testing.expectEqual(5, iter.curr());

    try testing.expectEqual(null, iter.next());
    try testing.expectEqual(null, iter.curr());
}

