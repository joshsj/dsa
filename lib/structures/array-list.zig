const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = std.mem.Allocator;

const SliceIterator = @import("../algorithms/slice/iterator.zig").SliceIterator;

// TODO std lib optimises growth with resize()
pub fn ArrayList(comptime T: type) type {
    return struct {
        const Self = @This();
        const DefaultCapacity = 10; // We Java now boys
        const DefaultGrowthFactor = 2;

        allocator: Allocator,
        /// Std lib uses a slice, I'm using a ptr
        /// Not copying the std lib because
        ///   1. I wouldn't have thought to use a slice
        ///   2. I don't think it's a better (or worse) interface
        ///   3. Doing the same thing is boring
        items: [*]T,
        len: usize,
        capacity: usize,

        pub fn init(allocator: Allocator) Allocator.Error!Self {
            return initCapacity(allocator, DefaultCapacity);
        }

        pub fn initCapacity(allocator: Allocator, capacity: usize) Allocator.Error!Self {
            const items = try allocator.alloc(T, capacity);

            return Self {
                .allocator = allocator,
                .capacity = capacity,
                .items = items.ptr,
                .len = 0
            };
        }

        pub fn fromIterator(allocator: Allocator, iter: anytype) Allocator.Error!Self {
            var self = try init(allocator);
            errdefer self.deinit();

            while (try iter.next()) |curr| {
                try self.addLast(curr);
            }

            return self;
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items[0..self.capacity]);
            // TODO reset capacity to 0?
        }

        /// O(n)
        pub fn addFirst(self: *Self, value: T) Allocator.Error!void {
            if (self.len == self.capacity) {
                try self.growToCapacityWithEmptyIndex(self.capacity * DefaultGrowthFactor, 0);
            } else if (self.len > 0) {
                self.shiftFromIndex(0);
            }

            self.items[0] = value;
            self.len += 1;
        }

        /// O(n)
        pub fn addAt(self: *Self, index: usize, value: T) Allocator.Error!void {
            if (index > self.len) {
                // TODO OOB
                return;
            }

            if (index == self.len) {
                return try self.addLast(value);
            }

            if (index == 0) {
                return try self.addFirst(value);
            }

            // 0 < index < self.len

            if (self.len == self.capacity) {
                try self.growToCapacityWithEmptyIndex(self.capacity * DefaultGrowthFactor, index);
            } else {
                self.shiftFromIndex(index);
            }

            self.items[index] = value;
            self.len += 1;
        }

        /// O(1)
        pub fn addLast(self: *Self, value: T) Allocator.Error!void {
            if (self.len == self.capacity) {
                const new_mem = try self.allocator.alloc(T, self.capacity * DefaultGrowthFactor);

                // Use slice of self to inform memcpy of length
                const items_slice = self.slice();

                @memcpy(new_mem.ptr, items_slice);
                self.allocator.free(items_slice);

                self.items = new_mem.ptr;
                self.capacity = new_mem.len;
            }

            self.items[self.len] = value;
            self.len += 1;
        }

        pub fn removeFirst(self: *Self) ?T {
            return self.removeAt(0);
        }

        pub fn removeAt(self: *Self, index: usize) ?T {
            if (index + 1 > self.len) {
                return null;
            }

            if (index + 1 == self.len) {
                return self.removeLast();
            }

            // 0 <= index < self.len
            
            const value = self.items[index];

            const src_slice = self.items[index + 1..self.len];
            const dest_slice = self.items[index..self.len - 1];

            mem.copyForwards(T, dest_slice, src_slice);

            self.len -= 1;

            return value;
        }

        /// O(1)
        pub fn removeLast(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }

            self.len -= 1;
            return self.items[self.len];
        }

        /// O(1)
        pub fn getAt(self: Self, index: usize) ?T {
            return if (index + 1 <= self.len) self.items[index] else null;
        }

        /// O(1)
        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn slice(self: Self) []T {
            return self.items[0..self.len];
        }

        pub fn iterator(self: Self) SliceIterator(T) {
            return SliceIterator(T).new(self.slice());
        }

        fn growToCapacityWithEmptyIndex(self: *Self, capacity: usize, index: usize) Allocator.Error!void {
            const left_slice = self.items[0..index];
            const right_slice = self.items[index..self.len];

            const new_mem = try self.allocator.alloc(T, capacity);

            @memcpy(new_mem.ptr, left_slice);
            @memcpy(new_mem.ptr + index + 1, right_slice);
            self.allocator.free(self.slice());

            self.items = new_mem.ptr;
            self.capacity = new_mem.len;
        }

        fn shiftFromIndex(self: Self, index: usize) void {
            const src_slice = self.items[index..self.len];
            const dest_slice = self.items[index + 1..self.len + 1];

            mem.copyBackwards(T, dest_slice, src_slice);
        }
    };
}

const TestList = ArrayList(u8);

test "when init() then list has the default capacity" {
    const list = try TestList.init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(TestList.DefaultCapacity, list.capacity);
}

test "when init() then list has no items" {
    const list = try TestList.init(testing.allocator);
    defer list.deinit();

    try testing.expectEqual(0, list.len);
}

test "when initCapacity() then list has the specified capacity" {
    const list = try TestList.initCapacity(testing.allocator, 5);
    defer list.deinit();

    try testing.expectEqual(5, list.capacity);
}

test "when initCapacity() then list has no items" {
    var list = try TestList.initCapacity(testing.allocator, 5);
    defer list.deinit();

    try testing.expectEqual(0, list.len);
}

test "given iterator when fromIterator() then list has items from iterator" {
    const items = [_]u8 { 1, 2, 3, 4, };
    var iter = SliceIterator(u8).new(&items);

    var list = try ArrayList(u8).fromIterator(testing.allocator, &iter);
    defer list.deinit();

    try testing.expectEqualSlices(u8, &items, list.slice());
}

test "given len < capacity when addLast() then does not grow and value is inserted at [len]" {
    var onceAllocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    var list = try TestList.init(onceAllocator.allocator());
    defer list.deinit();

    try list.addLast(6);
    try list.addLast(9);

    try testing.expectEqual(2, list.len);
    try testing.expectEqual(TestList.DefaultCapacity, list.capacity);

    const expected = [_]u8 { 6, 9 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

test "given len == capacity when addLast() then grows and value is inserted at [len]" {
    var list = try TestList.initCapacity(testing.allocator, 2);
    defer list.deinit();

    try list.addLast(6);
    try list.addLast(9);
    try list.addLast(12);

    try testing.expectEqual(3, list.len);
    try testing.expectEqual(4, list.capacity);

    const expected = [_]u8 { 6, 9, 12 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

test "given len < capacity when addFirst() then does not grow and items are shifted by 1 and value is inserted at [0]" {
    var onceAllocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    var list = try TestList.init(onceAllocator.allocator());
    defer list.deinit();

    try list.addFirst(6);
    try list.addFirst(9);

    try testing.expectEqual(2, list.len);
    try testing.expectEqual(TestList.DefaultCapacity, list.capacity);

    const expected = [_]u8 { 9, 6 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

test "given len == capacity when addFirst() then grows and items are shifted by 1 and value is inserted at [0]" {
    var list = try TestList.initCapacity(testing.allocator, 2);
    defer list.deinit();

    try list.addFirst(6);
    try list.addFirst(9);
    try list.addFirst(12);

    try testing.expectEqual(3, list.len);
    try testing.expectEqual(4, list.capacity);

    const expected = [_]u8 { 12, 9, 6 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

test "given len < capacity when addAt(middle) then does not grow and subsequent items are shifted by 1 and value is inserted at [middle]" {
    var onceAllocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    var list = try TestList.init(onceAllocator.allocator());
    defer list.deinit();

    try list.addLast(6);
    try list.addLast(12);
    try list.addLast(15);

    try list.addAt(1, 9);

    try testing.expectEqual(4, list.len);
    try testing.expectEqual(TestList.DefaultCapacity, list.capacity);

    const expected = [_]u8 { 6, 9, 12, 15 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

test "given len == capacity when addAt(middle) then grows and subsequent items are shifted by 1 and value is inserted at [middle]" {
    var list = try TestList.initCapacity(testing.allocator, 2);
    defer list.deinit();

    try list.addLast(6);
    try list.addLast(12);
    try list.addLast(15);

    try list.addAt(1, 9);

    try testing.expectEqual(4, list.len);
    try testing.expectEqual(4, list.capacity);

    const expected = [_]u8 { 6, 9, 12, 15 };

    try testing.expectEqualSlices(u8, &expected, list.slice());
}

