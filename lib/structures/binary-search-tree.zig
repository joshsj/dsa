const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const ArrayList = @import("../structures/array-list.zig").ArrayList;

const Node = @import("binary-node.zig").BinaryNode;
const DepthFirstIterator = @import("../algorithms/tree/iterator.zig").DepthFirstIterator;
const BreadthFirstIterator = @import("../algorithms/tree/iterator.zig").BreadthFirstIterator;

const search = @import("../algorithms/tree/search.zig");

const common = @import("../common.zig");
const Compare = common.Compare;
const defaultCompare = common.defaultCompare;

fn addOrdered(comptime T: type, maybeCurr: ?*Node(T), node: *Node(T), compare: *const Compare(T)) *Node(T) {
    if (maybeCurr) |curr| {
        if (compare(node.value, curr.value) == .gt) {
            curr.right = addOrdered(T, curr.right, node, compare);
        } else {
            curr.left = addOrdered(T, curr.left, node, compare);
        }

        return curr;
    } else {
        return node;
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

            self.root = addOrdered(T, self.root, node, self.compare);
        }

        pub fn find(self: Self, needle: T) ?*const Node {
            return search.binary(T, self.compare, self.root, needle);
        }

        pub fn depthFirstIterator(
            self: Self,
            order: DepthFirstIterator(T).Order
        ) DepthFirstIterator(T) {
            // TODO: return empty iterator when self.root is null
            return self.root.?.depthFirstIterator(self.allocator, order);
        }

        pub fn breadthFirstIterator(self: Self) BreadthFirstIterator(T) {
            // TODO: return empty iterator when self.root is null
            return self.root.?.breadthFirstIterator(self.allocator);
        }
    };
}

test "add" {
    var tree = BinarySearchTree(u8).init(testing.allocator);
    defer tree.deinit();

    try tree.add(5);
    try tree.add(7);
    try tree.add(3);
    try tree.add(1);
    try tree.add(2);
    try tree.add(2);
    try tree.add(8);

    // In-order traversal perserves order
    var iter = tree.depthFirstIterator(.in);
    defer iter.deinit();

    var sink = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer sink.deinit();

    const expected = [_]u8 { 1, 2, 2, 3, 5, 7, 8 };

    try testing.expectEqualSlices(u8, &expected, sink.slice());
}

