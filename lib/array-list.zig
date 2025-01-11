const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

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
            const mem = try allocator.alloc(T, capacity);

            return Self {
                .allocator = allocator,
                .capacity = capacity,
                .items = mem.ptr,
                .len = 0
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items[0..self.capacity]);
            // TODO reset capacity to 0?
        }

        /// O(n)
        pub fn grow(self: *Self) Allocator.Error!void {
            try self.growByFactor(DefaultGrowthFactor);
        }

        /// O(n)
        pub fn growByFactor(self: *Self, factor: usize) Allocator.Error!void {
            try self.growToCapacity(self.capacity * factor);
        }

        /// O(n)
        pub fn growToCapacity(self: *Self, capacity: usize) Allocator.Error!void {
            if (capacity <= self.capacity) {
                return;
            }

            // TODO std lib optimises with resize()
            const new_mem = try self.allocator.alloc(T, capacity);

            // Use slice of self to inform memcpy of length
            const items_slice = self.toSlice();

            @memcpy(new_mem.ptr, items_slice);
            self.allocator.free(items_slice);

            self.items = new_mem.ptr;
            self.capacity = new_mem.len;
        }

        /// Convenience method, needed because self.items is only a ptr
        pub fn toSlice(self: Self) []T {
            return self.items[0..self.len];
        }

        /// O(n)
        pub fn addFirst(self: *Self, value: T) Allocator.Error!void {
            const items_slice = self.toSlice();

            if (self.len == self.capacity) {
                const new_mem = try self.allocator.alloc(T, self.capacity * DefaultGrowthFactor);

                // Copy with offset to leave index 0 open
                @memcpy(new_mem.ptr + 1, items_slice);
                self.allocator.free(items_slice);
            
                self.items = new_mem.ptr;
                self.capacity = new_mem.len;
            } else if (self.len > 0) {
                @memcpy(items_slice.ptr + 1, items_slice);
            }

            self.items[0] = value;
            self.len += 1;
        }

        // O(1)
        pub fn addLast(self: *Self, value: T) Allocator.Error!void {
            if (self.len == self.capacity) {
                try self.grow();
            }

            self.items[self.len] = value;
            self.len += 1;
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

test "given len < capacity when addLast() then does not grow and value is inserted at [len]" {
    var onceAllocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    var list = try TestList.init(onceAllocator.allocator());
    defer list.deinit();

    try list.addLast(6);
    try list.addLast(9);

    try testing.expectEqual(2, list.len);

    const expected = [_]u8 { 6, 9 };

    try testing.expectEqualSlices(u8, &expected, list.toSlice());
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

    try testing.expectEqualSlices(u8, &expected, list.toSlice());
}

test "given len < capacity when addFirst() then does not grow and items are shifted by 1 and value is inserted at [0]" {
    var onceAllocator = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 1 });

    var list = try TestList.init(onceAllocator.allocator());
    defer list.deinit();

    try list.addFirst(6);
    try list.addFirst(9);

    try testing.expectEqual(2, list.len);

    const expected = [_]u8 { 9, 6 };

    try testing.expectEqualSlices(u8, &expected, list.toSlice());
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

    try testing.expectEqualSlices(u8, &expected, list.toSlice());
}
