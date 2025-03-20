const std = @import("std");
const testing = @import("testing.zig");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Equal = common.Equal;
const Hash = common.Hash;

pub fn HashSet(comptime T: type) type {
    return struct {
        const DefaultCapacity = 4; // Picked at random
        const LoadFactor: f32 = 0.75; // Stolen from the internet

        const Self = @This();
        const Iterator = @import("hash-set.iterator.zig").HashSetIterator(T);

        pub const Context = struct { hash: *const Hash(T), equal: *const Equal(T) };

        pub const FullBucket = struct { value: T, hash_value: usize, };
        pub const Bucket = union(enum) {
            empty,
            deleted,
            full: FullBucket,
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
                .buckets = try alloc(allocator, capacity),
                .ctx = ctx,
            };

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
            if (self.loadFactor(1) > LoadFactor) {
                try self.rehash();
            }

            const hash_value = self.ctx.hash(value);
            const head_i = hash_value % self.buckets.len;
            var probe_i: usize = 0;

            var first_deleted_p: ?*Bucket = null;

            // TODO: optimize best-case
            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const bucket_p = &self.buckets[(head_i + probe_i) % self.buckets.len];

                switch (bucket_p.*) {
                    .empty => {
                        (first_deleted_p orelse bucket_p).* = Bucket {
                            .full = .{ .value = value, .hash_value = hash_value }
                        };

                        self.len += 1;
                        return true;
                    },

                    .full => |full| if (full.hash_value == hash_value and self.ctx.equal(full.value, value)) return false,

                    .deleted => if (first_deleted_p == null) { first_deleted_p = bucket_p; }
                }
            }

            unreachable;
        }

        pub fn remove(self: *Self, value: T) ?T {
            if (self.len == 0) {
                return null;
            }

            const bucket_p = self.bucketContaining(value) orelse return null;

            defer bucket_p.* = .deleted;
            defer self.len -= 1;
            return bucket_p.full.value;
        }

        pub fn has(self: Self, value: T) bool {
            return self.bucketContaining(value) != null;
        }

        pub fn iter(self: Self) Iterator {
            return Iterator.init(self);
        }

        pub fn rehash(self: *Self) Allocator.Error!void {
            const buckets = try alloc(self.allocator, self.buckets.len * 2);

            for (self.buckets) |bucket| {
                const full = if (bucket == .full) bucket.full else continue;

                const head_i = full.hash_value % buckets.len;
                var probe_i: usize = 0;

                while (probe_i < buckets.len) : (probe_i += 1) {
                    const bucket_p = &buckets[(head_i + probe_i) % buckets.len];

                    if (bucket_p.* == .empty) {
                        bucket_p.* = Bucket { .full = full };
                        break;
                    }
                }
            }

            self.allocator.free(self.buckets);
            self.buckets = buckets;
        }

        fn loadFactor(self: Self, plus: usize) f32 {
            // TODO: not safe!
            const len: f32 = @floatFromInt(self.len + plus);
            const cap: f32 = @floatFromInt(self.buckets.len);

            return len / cap;
        }

        fn bucketContaining(self: Self, value: T) ?*Bucket {
            const hash_value = self.ctx.hash(value);
            const head_i = hash_value % self.buckets.len;
            
            var probe_i: usize = 0;

            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const bucket_p = &self.buckets[(head_i + probe_i) % self.buckets.len];

                switch (bucket_p.*) {
                    .empty => return null,
                    .deleted => {},
                    .full => |full| {
                        if (full.hash_value == hash_value and self.ctx.equal(full.value, value)) {
                            return bucket_p;
                        }
                    }
                }
            }

            return null;
        }

        fn alloc(allocator: Allocator, len: usize) Allocator.Error![]Bucket {
            const buckets = try allocator.alloc(Bucket, len);
            @memset(buckets, Bucket.empty);
            return buckets;
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
    try testing.expectEqual(0, set.len);
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
    try testing.expectEqual(1, set.len);
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
    try testing.expectEqual(2, set.len);
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
    try testing.expectEqual(3, set.len);
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
    try testing.expectEqual(1, set.len);
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
    try testing.expectEqual(2, set.len);
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
    try testing.expectEqual(2, set.len);
}

test "add(value) rehashes when the load factor is crossed" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(2); // 2 => 2
    _ = try set.add(4); // 4 => 4
    _ = try set.add(6); // 1 => 6

    _ = try set.add(8); // 8 => 8

    try testing.expectEqualSlices(
        TestSet.Bucket,
        &[_]TestSet.Bucket {
            TestSet.Bucket.empty,
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 2, .hash_value = 2 } },
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 4, .hash_value = 4 } },
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 6, .hash_value = 6 } },
            TestSet.Bucket.empty,
            TestSet.Bucket { .full = .{ .value = 8, .hash_value = 8 } },
            TestSet.Bucket.empty,
        },
        set.buckets
    );
    try testing.expectEqual(4, set.len);
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
    try testing.expectEqual(0, set.len);
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
    try testing.expectEqual(2, set.len);
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
    try testing.expectEqual(3, set.len);
}

test "has(value) returns true when value is present" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);

    try testing.expect(set.has(2));
}

test "has(value) returns false when value is not present" {
    var set = try testSet(5);
    defer set.deinit();

    _ = try set.add(1);
    _ = try set.add(2);
    _ = try set.add(3);

    try testing.expect(!set.has(5));
}
