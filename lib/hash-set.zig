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
            full: struct { value: T, hash_value: usize, }
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
            const hash_value = self.ctx.hash(value);
            const head_i = hash_value % self.buckets.len;
            var probe_i: usize = 0;

            var first_deleted_i: ?usize = null;

            // TODO: optimize best-case
            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const i = (head_i + probe_i) % self.buckets.len;

                switch (self.buckets[i]) {
                    .empty => {
                        self.buckets[first_deleted_i orelse i] = Bucket {
                            .full = .{ .value = value, .hash_value = hash_value }
                        };

                        return true;
                    },

                    .full => |full| if (full.hash_value == hash_value and self.ctx.equal(full.value, value)) return false,

                    .deleted => if (first_deleted_i == null) { first_deleted_i = i; }
                }
            }

            @panic("todo resize");
        }

        pub fn remove(self: Self, value: T) ?T {
            const hash_value = self.ctx.hash(value);
            const head_i = hash_value % self.buckets.len;
            
            var probe_i: usize = 0;

            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const i = (head_i + probe_i) % self.buckets.len;

                switch (self.buckets[i]) {
                    .empty => return null,
                    .deleted => {},
                    .full => |full| {
                        if (full.hash_value == hash_value and self.ctx.equal(full.value, value)) {
                            defer self.buckets[i] = .deleted;
                            return full.value;
                        }
                    }
                }
            }

            return null;
        }
    };
}

const TestSet = HashSet(usize);
fn testSet(capacity: usize) Allocator.Error!TestSet {
    return try TestSet.initCapacity(
        testing.allocator,
        TestSet.Context {
            .equal = common.defaultEqual(usize),
            .hash = common.identity(usize),
        },
        capacity
    );
}

test "init() intializes with empty buckets" {
    var set = try testSet(3);
    defer set.deinit();

    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { TestSet.Bucket.empty } ** 3,
        set.buckets
    );
}

test "add(value) inserts into bucket when value computes to empty bucket" {
    var set = try testSet(3);
    defer set.deinit();

    const ret = try set.add(1);

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "add(value) inserts into bucket when value computes to probed bucket" {
    var set = try testSet(3);
    defer set.deinit();

    _ = try set.add(1);

    const ret = try set.add(4);

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket { .full = .{ .value = 4, .hash_value = 4 } },
        },
        set.buckets
    );
}

test "add(value) inserts into deleted bucket when value computes to probed bucket across deleted buckets" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);
    _ = set.remove(2);

    const ret = try set.add(7);

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket { .full = .{ .value = 7, .hash_value = 7 } },
            TestSet.Bucket { .full = .{ .value = 3, .hash_value = 3 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "add(value) does not insert when value is present at head bucket" {
    var set = try testSet(3);
    defer set.deinit();

    _ = try set.add(1);
    const ret = try set.add(1);

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "add(value) does not insert when value is present at probed bucket" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(6);
    _ = try set.add(1);
    const ret = try set.add(1);

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 6, .hash_value = 6 } },
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket.empty,
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "add(value) does not insert when value is present at probed bucket across deleted buckets" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(6);
    _ = try set.add(1);
    _ = try set.add(3);
    _ = set.remove(1);

    const ret = try set.add(3);

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestSet.Bucket, 
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 6, .hash_value = 6 } },
            TestSet.Bucket.deleted,
            TestSet.Bucket { .full = .{ .value = 3, .hash_value = 3 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "remove(value) marks the bucket as deleted when value present at head bucket" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(1);
    const ret = set.remove(1);

    try testing.expectEqual(1, ret);
    try testing.expectEqualSlices(
        TestSet.Bucket,
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket.deleted,
            TestSet.Bucket.empty,
            TestSet.Bucket.empty,
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "remove(value) marks the bucket as deleted when value present at probed bucket" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(11);
    _ = try set.add(6);
    _ = try set.add(1);

    const ret = set.remove(1);

    try testing.expectEqual(1, ret);
    try testing.expectEqualSlices(
        TestSet.Bucket,
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 11, .hash_value = 11 } },
            TestSet.Bucket { .full = .{ .value = 6, .hash_value = 6 } },
            TestSet.Bucket.deleted,
            TestSet.Bucket.empty,
        },
        set.buckets
    );
}

test "remove(value) returns null when value not present" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);

    const ret = set.remove(4);

    try testing.expectEqual(null, ret);
    try testing.expectEqualSlices(
        TestSet.Bucket,
        &[_]TestSet.Bucket { 
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 1, .hash_value = 1 } },
            TestSet.Bucket { .full = .{ .value = 2, .hash_value = 2 } },
            TestSet.Bucket { .full = .{ .value = 3, .hash_value = 3 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );

}

