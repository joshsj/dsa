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

const Going = enum { left, self, right };

fn VisitableNode(comptime T: type) type {
    return struct {
        node: *const BinaryNode(T),
        going: ?Going = null
    };
}

// TODO: should the nodes be allocated with stack mem?

/// O(n)
/// Depth-first
pub fn InOrderIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        root: *const BinaryNode(u8),
        path: Stack(*VisitableNode(T)),
        moved: bool = false,

        pub fn init(allocator: Allocator, root: *const BinaryNode(u8)) Self {
            return Self { 
                .path = Stack(*VisitableNode(T)).init(allocator), 
                .root = root
            };
        }

        pub fn deinit(self: *Self) void {
            self.path.deinit();
        }
        
        pub fn curr(self: Self) ?T {
            return if (self.moved and self.path.peek() != null) self.path.peek().?.node.value else null;
        }

        pub fn next(self: *Self) Allocator.Error!?T {
            if (!self.moved) {
                var node = VisitableNode(T) { .node = self.root };
                try self.path.push(&node);
                self.moved = true;
            }

            try self.move();

            return self.curr();
        }

        fn move(self: *Self) Allocator.Error!void {
            const c = if (self.path.peek()) |pls| pls else return;

            if (c.going == null) {
                c.going = .left;

                if (c.node.left) |left| {
                    var node = VisitableNode(T) { .node = left };
                    try self.path.push(&node);
                }

                try self.move();
                return;
            }

            if (c.going == .left) {
                c.going = .self;
                return;
            }
            
            if (c.going == .self) {
                c.going = .right;

                if (c.node.right) |right| {
                    var node = VisitableNode(T) { .node = right };

                    try self.path.push(&node);
                }

                try self.move();
                return;
            }

            if (c.going == .right) {
                _ = self.path.pop();
                try self.move();
                return;
            }
        }
        
    };
}

pub fn preOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    ctx: *TContext
) !void {
    if (node) |n| {
        try visit(n.value, ctx);
        try preOrder(TValue, TContext, n.left, visit, ctx);
        try preOrder(TValue, TContext, n.right, visit, ctx);
    }
}

/// O(n)
/// Depth-first
pub fn inOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    ctx: *TContext
) !void {
    if (node) |n| {
        try preOrder(TValue, TContext, n.left, visit, ctx);
        try visit(n.value, ctx);
        try preOrder(TValue, TContext, n.right, visit, ctx);
    }
}

/// O(n)
/// Depth-first
pub fn postOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    ctx: *TContext
) !void {
    if (node) |n| {
        try preOrder(TValue, TContext, n.left, visit, ctx);
        try preOrder(TValue, TContext, n.right, visit, ctx);
        try visit(n.value, ctx);
    }
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

test preOrder {
    var left = TestNode { .value = 7 };
    var right = TestNode { .value = 1 };

    var manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var context = TestContext { .values = try ArrayList(u8).init(testing.allocator) };
    defer context.values.deinit();

    const expected = [_]u8 { 4, 7, 1, };

    try preOrder(u8, TestContext, &manyNodes, &testVisit, &context);

    try testing.expectEqualSlices(u8, &expected, context.values.slice());
}

test inOrder {
    var left = TestNode { .value = 7 };
    var right = TestNode { .value = 1 };

    var manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var context = TestContext { .values = try ArrayList(u8).init(testing.allocator) };
    defer context.values.deinit();

    const expected = [_]u8 { 7, 4, 1, };

    try inOrder(u8, TestContext, &manyNodes, &testVisit, &context);

    try testing.expectEqualSlices(u8, &expected, context.values.slice());
}

test InOrderIterator {
    var left = TestNode { .value = 7 };
    var right = TestNode { .value = 1 };

    const manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var iter = InOrderIterator(u8).init(testing.allocator, &manyNodes);
    defer iter.deinit();

    try testing.expectEqual(null, iter.curr());

    try testing.expectEqual(7, iter.next());
    try testing.expectEqual(7, iter.curr());
}

test postOrder {
    var left = TestNode { .value = 7 };
    var right = TestNode { .value = 1 };

    var manyNodes = TestNode {
        .value = 4,
        .left = &left,
        .right = &right,
    };

    var context = TestContext { .values = try ArrayList(u8).init(testing.allocator) };
    defer context.values.deinit();

    const expected = [_]u8 { 7, 1, 4 };

    try postOrder(u8, TestContext, &manyNodes, &testVisit, &context);

    try testing.expectEqualSlices(u8, &expected, context.values.slice());
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

