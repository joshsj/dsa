const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const ArrayList = @import("./array-list.zig").ArrayList;

const common = @import("../common.zig");
const Compare = common.Compare;
const defaultCompare = common.defaultCompare;

fn parentIndex(i: usize) usize {
    return (i - 1) / 2;
}

// TODO: max heap also
pub fn MinHeap(comptime T: type) type {
    return struct {
        const Self = @This();

        items: ArrayList(T),
        compare: *const Compare(T),

        pub fn init(allocator: Allocator) Allocator.Error!Self {
            return initCompare(allocator, defaultCompare(T));
        }

        pub fn initCompare(allocator: Allocator, compare: *const Compare(T)) Allocator.Error!Self {
            return Self { 
                .items = try ArrayList(T).init(allocator),
                .compare = compare,
            };
        }

        pub fn deinit(self: Self) void {
            self.items.deinit();
        }

        pub fn add(self: *Self, value: T) Allocator.Error!void {
            try self.items.addLast(value);

            self.swim(self.items.len - 1);
        }

        fn swim(self: Self, i: usize) void {
            if (i == 0) {
                return;
            }

            const parent_i = parentIndex(i);
            const items = self.items.slice();
            
            if (items[parent_i] > items[i]) {
                mem.swap(T, &items[parent_i], &items[i]);
            }

            swim(self, parent_i);
        }
    };
}

///         1
///       /   \
///     2       5
///    / \     / \
///   4   3   8   6
///  /
/// 7
fn createHeap() Allocator.Error!MinHeap(u8) {
    var heap = try MinHeap(u8).init(testing.allocator);

    try heap.add(5);
    try heap.add(7);
    try heap.add(3);
    try heap.add(1);
    try heap.add(2);
    try heap.add(8);
    try heap.add(6);
    try heap.add(4);

    return heap;
}

test "add" {
    var heap = try createHeap();
    defer heap.deinit();

    const expected = [_]u8 { 1, 2, 5, 4, 3, 8, 6, 7, };

    try testing.expectEqualSlices(u8, &expected, heap.items.slice());
}

