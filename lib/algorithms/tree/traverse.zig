const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ArrayList = @import("../../structures/array-list.zig").ArrayList;
const BinaryNode = @import("../../structures/binary-node.zig").BinaryNode;
const Queue = @import("../../structures/queue.zig").Queue;
const Stack = @import("../../structures/stack.zig").Stack;

// TODO: not sure generics like this are better than anytype...

pub fn Visit(
    comptime TValue: type,
    comptime TContext: type
) type {
    // TODO: value by ref or value?
    return fn (value: TValue, ctx: *TContext) anyerror!void;
}

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
/// Depth-first
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

// TODO: iterators!
pub fn breadthFirst(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    ctx: *TContext,
    allocator: Allocator
) !void {
    if (node == null) {
        return;
    }

    var queue = Queue(*const BinaryNode(TValue)).init(allocator);
    defer queue.deinit();

    try queue.enqueue(node.?);

    while (queue.items.len > 0) {
        const curr = queue.deqeue().?;

        try visit(curr.value, ctx);
        
        if (curr.left) |left| { try queue.enqueue(left); }
        if (curr.right) |right| { try queue.enqueue(right); }
    }
}

const TestNode = BinaryNode(u8);
const TestContext = struct { values: ArrayList(u8) };

const testVisit: Visit(u8, TestContext) = struct {
    fn f(value: u8, ctx: *TestContext) !void {
        // We're gaming now
        try ctx.values.addLast(value);
    }
}.f;

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

test breadthFirst {
    var left_right = TestNode { .value = 2 };
    var left = TestNode { .value = 7, .right = &left_right };

    var right_left = TestNode { .value = 6 };
    var right = TestNode { .value = 1, .left = &right_left };

    var manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var context = TestContext { .values = try ArrayList(u8).init(testing.allocator) };
    defer context.values.deinit();

    const expected = [_]u8 { 4, 7, 1, 2, 6, };

    try breadthFirst(u8, TestContext, &manyNodes, &testVisit, &context, testing.allocator);

    try testing.expectEqualSlices(u8, &expected, context.values.slice());
}

