const std = @import("std");
const testing = std.testing;

const ArrayList = @import("../../structures/array-list.zig").ArrayList;
const BinaryNode = @import("../../structures/binary-node.zig").BinaryNode;

// TODO: not sure generics like this are better than anytype...

pub fn Visit(
    comptime TValue: type,
    comptime TContext: type
) type {
    // TODO: value by ref or value?
    return fn (value: TValue, ctx: *TContext) anyerror!void;
}

/// O(n)
/// Depth-first
pub fn preOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    context: *TContext
) !void {
    if (node) |n| {
        try visit(n.value, context);
        try preOrder(TValue, TContext, n.left, visit, context);
        try preOrder(TValue, TContext, n.right, visit, context);
    }
}

/// O(n)
/// Depth-first
pub fn inOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    context: *TContext
) !void {
    if (node) |n| {
        try preOrder(TValue, TContext, n.left, visit, context);
        try visit(n.value, context);
        try preOrder(TValue, TContext, n.right, visit, context);
    }
}

/// O(n)
/// Depth-first
pub fn postOrder(
    comptime TValue: type,
    comptime TContext: type,
    node: ?*const BinaryNode(TValue),
    visit: *const Visit(TValue, TContext),
    context: *TContext
) !void {
    if (node) |n| {
        try preOrder(TValue, TContext, n.left, visit, context);
        try preOrder(TValue, TContext, n.right, visit, context);
        try visit(n.value, context);
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

    try testing.expectEqualSlices(u8, &expected, context.values.toSlice());
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

    try testing.expectEqualSlices(u8, &expected, context.values.toSlice());
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

    try testing.expectEqualSlices(u8, &expected, context.values.toSlice());
}
 
