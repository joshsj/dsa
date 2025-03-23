const std = @import("std");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const testing = @import("testing.zig");

pub fn HashSet(comptime T: type) type {
    // I had this idea before I saw it in the docs
    // Must be doing something right
    const HashMap = @import("hash-map.zig").HashMap(T, void);

    return struct {
        const Self = @This();

        const Iterator = HashMap.Iterator;
        const Context = HashMap.Context;

        inner: HashMap,

        pub fn init(allocator: Allocator, ctx: HashMap.Context) Allocator.Error!Self {
            return Self {
                .inner = try HashMap.init(allocator, ctx),
            };
        }

        pub fn initCapacity(allocator: Allocator, ctx: HashMap.Context, capacity: usize) Allocator.Error!Self {
            return Self {
                .inner = try HashMap.initCapacity(allocator, ctx, capacity),
            };
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        /// O(1)
        pub fn add(self: *Self, value: T) Allocator.Error!bool {
            return self.inner.put(value, {});
        }

        /// O(1)
        pub fn remove(self: Self, value: T) ?T {
            return self.inner.remove(value);
        }

        /// O(1)
        pub fn has(self: Self, value: T) bool {
            return self.inner.has(value);
        }

        // TODO: key only iterator would be nice
        pub fn iter(self: Self) Iterator {
            return Iterator.init(self.inner);
        }
    };
}

