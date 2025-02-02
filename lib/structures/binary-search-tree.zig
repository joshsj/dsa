const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ArrayList = @import("../array-list.zig").ArrayList;

const Node = @import("binary-node.zig").BinaryNode;

const search = @import("../algorithms/tree/search.zig");

const common = @import("../common.zig");
const Compare = common.Compare;
const defaultCompare = common.defaultCompare;

// Returns a ptr to maybeCurr
// Allows recursive function to (effectively) assign its parent without a reference to it
fn addOrdered(comptime T: type, self: BinarySearchTree(T), maybeCurr: ?*Node(T), node: *Node(T)) *Node(T) {
    if (maybeCurr) |curr| {
        if (self.compare(node.value, curr.value) == .gt) {
            curr.right = addOrdered(T, self, curr.right, node);
        } else {
            curr.left = addOrdered(T, self, curr.left, node);
        }

        return curr;
    } else {
        return node;
    }
}

fn removeOrdered(comptime T: type, self: BinarySearchTree(T), maybeCurr: ?*Node(T), value: T) ?*Node(T) {
    if (maybeCurr) |curr| {
        const order = self.compare(value, curr.value);

        if (order == .lt) {
            curr.left = removeOrdered(T, self, curr.left, value);
            return curr;
        } 

        if (order == .gt) {
            curr.right = removeOrdered(T, self, curr.right, value);
            return curr;
        }

        if (curr.left != null and curr.right != null) {
            curr.value = findMin(T, curr.right.?).value;
            curr.right = removeMin(T, self, curr.right.?);
            return curr;
        }

        defer self.allocator.destroy(curr);
        return curr.left orelse curr.right;
    } else {
        return null;
    }
}

fn findMin(comptime T: type, root: *Node(T)) *Node(T) {
    var succ = root;
    while (succ.left) |next_succ| { succ = next_succ; }
    return succ;
}

fn removeMin(comptime T: type, self: BinarySearchTree(T), min: *Node(T)) ?*Node(T) {
    if (min.left) |left| {
        min.left = removeMin(T, self, left);
        return min;
    } else {
        defer self.allocator.destroy(min);
        return min.right;
    }
}

fn deinitNode(comptime T: type, allocator: Allocator, maybeNode: ?*Node(T)) void {
    if (maybeNode) |node| {
        deinitNode(T, allocator, node.left);
        deinitNode(T, allocator, node.right);

        allocator.destroy(node);
    }
}

pub fn BinarySearchTree(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        root: ?*Node(T),
        compare: *const Compare(T),

        pub fn init(allocator: Allocator) Self {
            return initCompare(allocator, defaultCompare(T));
        }

        pub fn initCompare(allocator: Allocator, compare: *const Compare(T)) Self {
            return Self {
                .allocator = allocator,
                .root = null,
                .compare = compare,
            };
        }

        pub fn deinit(self: *Self) void {
            deinitNode(T, self.allocator, self.root);

            self.root = null;
        }

        pub fn add(self: *Self, value: T) Allocator.Error!void {
            var node = try self.allocator.create(Node(T));
            node.value = value;
            node.left = null;
            node.right = null;

            self.root = addOrdered(T, self.*, self.root, node);
        }

        pub fn has(self: Self, needle: T) bool {
            return search.binary(T, self.compare, self.root, needle) != null;
        }

        pub fn remove(self: *Self, value: T) void {
            self.root = removeOrdered(T, self.*, self.root, value);
        }
    };
}

///     5
///   /   \
///  3     7
/// / \   / \ 
///1   4 6   8
/// \
///  2
fn createTree() !BinarySearchTree(u8) {
    var tree = BinarySearchTree(u8).init(testing.allocator);

    try tree.add(5);
    try tree.add(7);
    try tree.add(3);
    try tree.add(1);
    try tree.add(2);
    try tree.add(8);
    try tree.add(6);
    try tree.add(4);

    return tree;
}

test "add" {
    var tree = try createTree();
    defer tree.deinit();

    // In-order traversal perserves order
    var iter = tree.root.?.depthFirstIterator(testing.allocator, .in);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 1, 2, 3, 4, 5, 6, 7, 8 };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
}

test "remove" {
    var tree = try createTree();
    defer tree.deinit();

    // No children
    tree.remove(2);

    // Two children
    tree.remove(7);

    // One child
    tree.remove(8);

    var iter = tree.root.?.depthFirstIterator(testing.allocator, .in);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 1, 3, 4, 5, 6, };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
}

