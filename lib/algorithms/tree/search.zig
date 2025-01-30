const std = @import("std");
const testing = std.testing;

const BinaryNode = @import("../../structures/binary-node.zig").BinaryNode;
const BinarySearchTree = @import("../../structures/binary-search-tree.zig").BinarySearchTree;


const common = @import("../../common.zig");
const Compare = common.Compare;
const defaultCompare = common.defaultCompare;

/// O(h)
pub fn binary(
    comptime T: type,
    compare: *const Compare(T),
    haystack: ?*const BinaryNode(T),
    needle: T
) ?*const BinaryNode(T) {
    return if (haystack) |node| switch (compare(needle, node.value)) {
        .eq => node,
        .lt => binary(T, compare, node.left, needle),
        .gt => binary(T, compare, node.right, needle),
    } else null;
}

test "given a null haystack when binary() then returns null" {
    try testing.expectEqual(null, binary(u8, &defaultCompare(u8), null, 1));
}

test "given a tree when binary(exists) then returns node ptr" {
    var tree = BinarySearchTree(u8).init(testing.allocator);
    defer tree.deinit();

    try tree.add('3');
    try tree.add('5');
    try tree.add('4');
    try tree.add('6');

    const expected = tree.root.?.right.?.left.?;

    try testing.expectEqual(expected, binary(u8, &defaultCompare(u8), tree.root, '4'));
}

test "given a tree when binary(not exists) then returns null" {
    var tree = BinarySearchTree(u8).init(testing.allocator);
    defer tree.deinit();

    try tree.add('3');
    try tree.add('5');
    try tree.add('4');
    try tree.add('6');

    try testing.expectEqual(null, binary(u8, &defaultCompare(u8), tree.root, '1'));
}

