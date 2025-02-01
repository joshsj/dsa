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

fn leftIndex(i: usize) usize {
    return (2 * i) + 1;
}

fn rightIndex(i: usize) usize {
    return (2 * i) + 2;
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

        pub fn remove(self: *Self) ?T {
            if (self.items.len <= 1) {
                return self.items.removeLast();
            }

            const max = self.items.removeLast().?;
            const items = self.items.slice();
            const min = items[0];

            items[0] = max;
            self.sink(0);

            return min;
        }

        fn swim(self: Self, curr_i: usize) void {
            if (curr_i == 0) {
                return;
            }

            const parent_i = parentIndex(curr_i);

            const items = self.items.slice();
            
            if (self.compare(items[parent_i], items[curr_i]) == .gt) {
                mem.swap(T, &items[parent_i], &items[curr_i]);
            }

            swim(self, parent_i);
        }

        fn sink(self: Self, curr_i: usize) void {
            const min_child_i = self.minChildIndex(curr_i) orelse return;

            const items = self.items.slice();

            if (self.compare(items[curr_i], items[min_child_i]) == .gt) {
                mem.swap(T, &items[curr_i], &items[min_child_i]);

                self.sink(min_child_i);
            }
        }

        fn minChildIndex(self: Self, i: usize) ?usize {
            const left_i = leftIndex(i);
            const right_i = rightIndex(i);

            if (left_i >= self.items.len) {
                return null;
            }

            if (right_i >= self.items.len) {
                return left_i;
            }

            const items = self.items.slice();

            return switch (self.compare(items[left_i], items[right_i])) {
                .lt, .eq => left_i,
                .gt => right_i
            };
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

fn expectRemove(heap: *MinHeap(u8), removed: ?u8, remaining: []const u8) !void {
    try testing.expectEqual(removed, heap.remove());
    try testing.expectEqualSlices(u8, remaining, heap.items.slice());
}

test "remove" {
    var heap = try createHeap();
    defer heap.deinit();

    try expectRemove(&heap, 1, &[_]u8{  2, 3, 5, 4, 7, 8, 6, });

    try expectRemove(&heap, 2, &[_]u8{  3, 4, 5, 6, 7, 8, });

    try expectRemove(&heap, 3, &[_]u8{  4, 6, 5, 8, 7, });

    try expectRemove(&heap, 4, &[_]u8{  5, 6, 7, 8, });

    try expectRemove(&heap, 5, &[_]u8{  6, 8, 7, });

    try expectRemove(&heap, 6, &[_]u8{ 7, 8, });

    try expectRemove(&heap, 7, &[_]u8{ 8, });

    try expectRemove(&heap, 8, &[_]u8{});

    try expectRemove(&heap, null, &[_]u8{});
}

