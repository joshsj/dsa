const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const ArrayList = @import("./array-list.zig").ArrayList;

const common = @import("../common.zig");
const CompareOrder = common.CompareOrder;
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

pub fn Heap(comptime T: type) type {
    return struct {
        const Self = @This();

        const Order = enum { min, max };

        items: ArrayList(T),
        compare: *const Compare(T),
        order: Order,
        compareOrder: CompareOrder,

        pub fn init(allocator: Allocator, order: Order) Allocator.Error!Self {
            return initCompare(allocator, order, defaultCompare(T));
        }

        pub fn initCompare(
            allocator: Allocator,
            order: Order,
            compare: *const Compare(T)
        ) Allocator.Error!Self {
            return Self { 
                .items = try ArrayList(T).init(allocator),
                .compare = compare,
                .order = order,
                .compareOrder = switch (order) {
                    .min => .gt,
                    .max => .lt
                }
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

            const last = self.items.removeLast().?;
            const items = self.items.slice();
            const first = items[0];

            items[0] = last;
            self.sink(0);

            return first;
        }

        fn swim(self: Self, curr_i: usize) void {
            if (curr_i == 0) {
                return;
            }

            const parent_i = parentIndex(curr_i);

            const items = self.items.slice();
            
            if (self.compare(items[parent_i], items[curr_i]) == self.compareOrder) {
                mem.swap(T, &items[parent_i], &items[curr_i]);

                self.swim(parent_i);
            }
        }

        fn sink(self: Self, curr_i: usize) void {
            const next_child_i = self.nextChildIndex(curr_i) orelse return;

            const items = self.items.slice();

            if (self.compare(items[curr_i], items[next_child_i]) == self.compareOrder) {
                mem.swap(T, &items[curr_i], &items[next_child_i]);

                self.sink(next_child_i);
            }
        }

        fn nextChildIndex(self: Self, i: usize) ?usize {
            const left_i = leftIndex(i);
            const right_i = rightIndex(i);

            if (left_i >= self.items.len) {
                return null;
            }

            if (right_i >= self.items.len) {
                return left_i;
            }

            const items = self.items.slice();

            return
                if (self.compare(items[left_i], items[right_i]) == self.compareOrder) right_i
                else left_i;
        }
    };
}

///        Min               Max     
///         1                 8      
///       /   \             /   \    
///     2       5         5       7  
///    / \     / \       / \     / \ 
///   4   3   8   6     4   2   3   6
///  /                 /             
/// 7                 1              
fn createHeap(order: Heap(u8).Order) Allocator.Error!Heap(u8) {
    var heap = try Heap(u8).init(testing.allocator, order);

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

fn expectRemove(heap: *Heap(u8), removed: ?u8, remaining: []const u8) !void {
    try testing.expectEqual(removed, heap.remove());
    try testing.expectEqualSlices(u8, remaining, heap.items.slice());
}

test ".min add()" {
    var heap = try createHeap(.min);
    defer heap.deinit();

    const expected = [_]u8 { 1, 2, 5, 4, 3, 8, 6, 7, };

    try testing.expectEqualSlices(u8, &expected, heap.items.slice());
}

test ".min remove()" {
    var heap = try createHeap(.min);
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

test "max add()" {
    var heap = try createHeap(.max);
    defer heap.deinit();

    const expected = [_]u8 { 8, 5, 7, 4, 2, 3, 6, 1, };

    try testing.expectEqualSlices(u8, &expected, heap.items.slice());
}

test "max remove()" {
    var heap = try createHeap(.max);
    defer heap.deinit();

    try expectRemove(&heap, 8, &[_]u8 { 7, 5, 6, 4, 2, 3, 1, });

    try expectRemove(&heap, 7, &[_]u8 { 6, 5, 3, 4, 2, 1, });

    try expectRemove(&heap, 6, &[_]u8 { 5, 4, 3, 1, 2, });

    try expectRemove(&heap, 5, &[_]u8 { 4, 2, 3, 1, });
    
    try expectRemove(&heap, 4, &[_]u8 { 3, 2, 1, });

    try expectRemove(&heap, 3, &[_]u8 { 2, 1, });
    
    try expectRemove(&heap, 2, &[_]u8 { 1, });

    try expectRemove(&heap, 1, &[0]u8{});

    try expectRemove(&heap, null, &[0]u8{});
}

