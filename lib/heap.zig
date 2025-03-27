const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const ArrayList = @import("array-list.zig").ArrayList;

const common = @import("common.zig");
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

pub fn Heap(comptime TPriority: type, comptime TValue: type) type {
    return struct {
        const Self = @This();

        const Entry = struct { priority: TPriority, value: TValue, };

        const Order = enum { min, max };

        items: ArrayList(Entry),
        compare: *const Compare(TPriority),
        order: Order,
        compareOrder: CompareOrder,

        pub fn init(allocator: Allocator, order: Order) Allocator.Error!Self {
            return initCompare(allocator, order, defaultCompare(TPriority));
        }

        pub fn initCompare(
            allocator: Allocator,
            order: Order,
            compare: *const Compare(TPriority)
        ) Allocator.Error!Self {
            return Self { 
                .items = try ArrayList(Entry).init(allocator),
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

        pub fn add(self: *Self, priority: TPriority, value: TValue) Allocator.Error!void {
            try self.items.addLast(.{ .priority = priority, .value = value });

            self.swim(self.items.len - 1);
        }

        pub fn remove(self: *Self) ?Entry {
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
            
            if (self.compare(items[parent_i].priority, items[curr_i].priority) == self.compareOrder) {
                mem.swap(Entry, &items[parent_i], &items[curr_i]);

                self.swim(parent_i);
            }
        }

        fn sink(self: Self, curr_i: usize) void {
            const next_child_i = self.nextChildIndex(curr_i) orelse return;

            const items = self.items.slice();

            if (self.compare(items[curr_i].priority, items[next_child_i].priority) == self.compareOrder) {
                mem.swap(Entry, &items[curr_i], &items[next_child_i]);

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
                if (self.compare(items[left_i].priority, items[right_i].priority) == self.compareOrder) right_i
                else left_i;
        }
    };
}

const TestHeap = Heap(u8, void);

inline fn entries(priorities: []const u8) []TestHeap.Entry {
    var ret: [priorities.len]TestHeap.Entry = undefined;

    for (priorities, 0..) |p, i| {
        ret[i] = TestHeap.Entry { .priority = p, .value = {} };
    }

    return &ret;
}

///        Min               Max     
///         1                 8      
///       /   \             /   \    
///     2       5         5       7  
///    / \     / \       / \     / \ 
///   4   3   8   6     4   2   3   6
///  /                 /             
/// 7                 1              
fn createHeap(order: TestHeap.Order) !TestHeap {
    var heap = try TestHeap.init(testing.allocator, order);

    try heap.add(5, {});
    try heap.add(7, {});
    try heap.add(3, {});
    try heap.add(1, {});
    try heap.add(2, {});
    try heap.add(8, {});
    try heap.add(6, {});
    try heap.add(4, {});

    try testing.expectEqual(8, heap.items.len);

    return heap;
}

fn expectRemove(heap: *TestHeap, priority: ?u8, remaining: []const TestHeap.Entry) !void {
    const entry = if (priority) |p| TestHeap.Entry { .priority = p, .value = {} } else null;

    try testing.expectEqual(entry, heap.remove());
    try testing.expectEqualSlices(TestHeap.Entry, remaining, heap.items.slice());
}

test ".min add()" {
    var heap = try createHeap(.min);
    defer heap.deinit();

    const expected = entries(&[_]u8 { 1, 2, 5, 4, 3, 8, 6, 7, });

    try testing.expectEqualSlices(TestHeap.Entry, expected, heap.items.slice());
}

test ".min remove()" {
    var heap = try createHeap(.min);
    defer heap.deinit();

    try expectRemove(&heap, 1, entries(&[_]u8{  2, 3, 5, 4, 7, 8, 6, }));

    try expectRemove(&heap, 2, entries(&[_]u8{  3, 4, 5, 6, 7, 8, }));

    try expectRemove(&heap, 3, entries(&[_]u8{  4, 6, 5, 8, 7, }));

    try expectRemove(&heap, 4, entries(&[_]u8{  5, 6, 7, 8, }));

    try expectRemove(&heap, 5, entries(&[_]u8{  6, 8, 7, }));

    try expectRemove(&heap, 6, entries(&[_]u8{ 7, 8, }));

    try expectRemove(&heap, 7, entries(&[_]u8{ 8, }));

    try expectRemove(&heap, 8, entries(&[_]u8{}));

    try expectRemove(&heap, null, &[0]TestHeap.Entry{});
}

test "max add()" {
    var heap = try createHeap(.max);
    defer heap.deinit();

    const expected = entries(&[_]u8 { 8, 5, 7, 4, 2, 3, 6, 1, });

    try testing.expectEqualSlices(TestHeap.Entry, expected, heap.items.slice());
}

test "max remove()" {
    var heap = try createHeap(.max);
    defer heap.deinit();

    try expectRemove(&heap, 8, entries(&[_]u8 { 7, 5, 6, 4, 2, 3, 1, }));

    try expectRemove(&heap, 7, entries(&[_]u8 { 6, 5, 3, 4, 2, 1, }));

    try expectRemove(&heap, 6, entries(&[_]u8 { 5, 4, 3, 1, 2, }));

    try expectRemove(&heap, 5, entries(&[_]u8 { 4, 2, 3, 1, }));
    
    try expectRemove(&heap, 4, entries(&[_]u8 { 3, 2, 1, }));

    try expectRemove(&heap, 3, entries(&[_]u8 { 2, 1, }));
    
    try expectRemove(&heap, 2, entries(&[_]u8 { 1, }));

    try expectRemove(&heap, 1, entries(&[0]u8{}));

    try expectRemove(&heap, null, entries(&[0]u8{}));
}

