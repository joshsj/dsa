const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Equal = common.Equal;
const Hash = common.Hash;

pub fn HashMap(comptime T: type) type {
    return struct {
        const InitialCapacity = 4; // Picked at random
        const Self = @This();
        const Context = struct { hash: *const Hash(T), equal: *const Equal(T) };

        allocator: Allocator,
        buckets: []?*const T,
        ctx: Context,
        len: usize = 0,

        pub fn init(allocator: Allocator, ctx: Context) Allocator.Error!Self {
            const self = Self {
                .allocator = allocator,
                .buckets = try allocator.alloc(?*const T, InitialCapacity),
                .ctx = ctx,
            };

            @memset(self.buckets, null);

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buckets);
            self.len = 0;
        }

        pub fn add(self: *Self, value: T) Allocator.Error!void {
            _ = self;
            _ = value;
        }

        fn calcIndex(self: Self, value: T) usize {
            return self.ctx.hash(value) % self.buckets.len;
        }
    };
}

const c = HashMap(usize).Context {
    .equal = &common.defaultEqual(usize),
    .hash = common.Identity(usize),
};

test "init" {
    var map = try HashMap(usize).init(testing.allocator, c);
    defer map.deinit();
}

