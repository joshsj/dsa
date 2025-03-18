const std = @import("std");
const testing = @import("testing.zig");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Equal = common.Equal;
const Hash = common.Hash;

pub fn HashSet(comptime T: type) type {
    return struct {
        const DefaultCapacity = 4; // Picked at random

        const Self = @This();

        const Context = struct { hash: *const Hash(T), equal: *const Equal(T) };

        const Bucket = union(enum) {
            empty,
            deleted,
            full: struct { value: T, hashValue: usize, }
        };

        allocator: Allocator,
        buckets: []Bucket,
        ctx: Context,
        len: usize = 0,

        pub fn init(allocator: Allocator, ctx: Context) Allocator.Error!Self {
            return initCapacity(allocator, ctx, DefaultCapacity);
        }

        pub fn initCapacity(allocator: Allocator, ctx: Context, capacity: usize) Allocator.Error!Self {
            const self = Self {
                .allocator = allocator,
                .buckets = try allocator.alloc(Bucket, capacity),
                .ctx = ctx,
            };

            @memset(self.buckets, Bucket.empty);

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buckets);
            self.len = 0;
        }

        /// Returns true if the value was added
        ///
        /// O(1)
        pub fn add(self: *Self, value: T) Allocator.Error!bool {
            const hashValue = self.ctx.hash(value);
            const origin = hashValue % self.buckets.len;

            switch (self.buckets[origin]) {
                .empty => {
                    self.buckets[origin] = Bucket {
                        .full = .{
                            .value = value,
                            .hashValue = hashValue
                        }
                    };

                    return true;
                },
                else => @panic("todo")
            }
        }
    };
}

const TestSet = HashSet(usize);

const testCtx = TestSet.Context {
    .equal = common.defaultEqual(usize),
    .hash = common.identity(usize),
};

test "init() intializes with empty buckets" {
    var set = try TestSet.initCapacity(testing.allocator, testCtx, 3);
    defer set.deinit();

    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { TestSet.Bucket.empty } ** 3,
        set.buckets
    );
}

test "add() to an empty bucket inserts at bucket index" {
    var set = try HashSet(usize).initCapacity(testing.allocator, testCtx, 3);
    defer set.deinit();

    const ret = try set.add(1);

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &([_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hashValue = 1 } },
            TestSet.Bucket.empty,
        }),
        set.buckets
    );
}

