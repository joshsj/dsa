const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ArrayList = @import("../../array-list.zig").ArrayList;
const BinaryNode = @import("../../structures/binary-node.zig").BinaryNode;
const Queue = @import("../../queue.zig").Queue;
const Stack = @import("../../stack.zig").Stack;

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
        root: *const BinaryNode(T),
        move: *const fn(*Self) Allocator.Error!void,
        moved: bool = false,

        pub fn init(
            allocator: Allocator, 
            root: *const BinaryNode(T),
            order: Order
        ) Self {
            return Self { 
                .allocator = allocator,
                .path = Stack(*GoingNode(T)).init(allocator), 
                .root = root,
                // TODO: data-driven logic would be cool
                // instead of the 3 separate methods
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
        root: *const BinaryNode(T),
        moved: bool = false,

        pub fn init(allocator: Allocator, root: *const BinaryNode(T),) Self {
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

    const root = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &root, .pre);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 4, 7, 2, 1, 5, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
    try testing.expectEqual(null, iter.curr());
}

test "in" {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const root = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &root, .in);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 7, 2, 4, 5, 1, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
    try testing.expectEqual(null, iter.curr());
}

test "post" {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const root = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = DepthFirstIterator(u8).init(testing.allocator, &root, .post);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 2, 7, 5, 1, 4};

    try testing.expectEqualSlices(u8, &expected, sink.slice());
    try testing.expectEqual(null, iter.curr());
}

test BreadthFirstIterator {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 5 };
    var right = TestNode { .value = 1, .left = &right_left };

    const root = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = BreadthFirstIterator(u8).init(testing.allocator, &root);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 4, 7, 1, 2, 5, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
    try testing.expectEqual(null, iter.curr());
}

