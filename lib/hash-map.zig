const std = @import("std");
const testing = @import("testing.zig");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Equal = common.Equal;
const Hash = common.Hash;

pub fn HashMap(comptime TKey: type, comptime TValue: type) type {
    return struct {
        const DefaultCapacity = 4; // Picked at random
        const LoadFactor: f64 = 0.75; // Stolen from the internet

        const Self = @This();
        const Iterator = @import("hash-map.iterator.zig").HashMapIterator(TKey, TValue);

        pub const Context = struct { hash: *const Hash(TKey), equal: *const Equal(TKey) };

        pub const Pair = struct { key: TKey, value: TValue };
        pub const FullBucket = struct { key: TKey, value: TValue, hash_value: usize, };
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
        pub fn add(self: *Self, key: TKey, value: TValue) Allocator.Error!bool {
            if (self.loadFactor(1) > LoadFactor) {
                try self.rehash();
            }

            const hash_value = self.ctx.hash(key);
            const head_i = hash_value % self.buckets.len;
            var probe_i: usize = 0;

            var first_deleted_p: ?*Bucket = null;

            // TODO: optimize best-case
            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const bucket_p = &self.buckets[(head_i + probe_i) % self.buckets.len];

                switch (bucket_p.*) {
                    .empty => {
                        (first_deleted_p orelse bucket_p).* = Bucket {
                            .full = .{ .key = key, .value = value, .hash_value = hash_value }
                        };

                        self.len += 1;
                        return true;
                    },

                    .full => |full| if (full.hash_value == hash_value and self.ctx.equal(full.key, key)) return false,

                    .deleted => if (first_deleted_p == null) { first_deleted_p = bucket_p; }
                }
            }

            unreachable;
        }

        pub fn remove(self: *Self, key: TKey) ?TValue {
            if (self.len == 0) {
                return null;
            }

            const bucket_p = self.bucketContaining(key) orelse return null;

            defer bucket_p.* = .deleted;
            defer self.len -= 1;
            return bucket_p.full.value;
        }

        pub fn has(self: Self, value: TKey) bool {
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

        fn bucketContaining(self: Self, key: TKey) ?*Bucket {
            const hash_value = self.ctx.hash(key);
            const head_i = hash_value % self.buckets.len;
            
            var probe_i: usize = 0;

            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const bucket_p = &self.buckets[(head_i + probe_i) % self.buckets.len];

                switch (bucket_p.*) {
                    .empty => return null,
                    .deleted => {},
                    .full => |full| {
                        if (full.hash_value == hash_value and self.ctx.equal(full.key, key)) {
                            return bucket_p;
                        }
                    }
                }
            }

            return null;
        }

        fn loadFactor(self: Self, plus: usize) f64 {
            // TODO: not safe!
            const len: f64 = @floatFromInt(self.len + plus);
            const cap: f64 = @floatFromInt(self.buckets.len);

            return len / cap;
        }

        fn alloc(allocator: Allocator, len: usize) Allocator.Error![]Bucket {
            const buckets = try allocator.alloc(Bucket, len);
            @memset(buckets, Bucket.empty);
            return buckets;
        }
    };
}

const Str = [:0]const u8;
const TestMap = HashMap(usize, Str);

fn testMap(capacity: usize) Allocator.Error!TestMap {
    return try TestMap.initCapacity(
        testing.allocator,
        TestMap.Context {
            .equal = common.defaultEqual(usize),
            .hash = common.identity(usize),
        },
        capacity
    );
}

test "init() intializes with empty buckets" {
    var map = try testMap(3);
    defer map.deinit();

    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { TestMap.Bucket.empty } ** 3,
        map.buckets
    );
    try testing.expectEqual(0, map.len);
}

test "add(value) inserts into bucket when value computes to empty bucket" {
    var map = try testMap(3);
    defer map.deinit();

    const ret = try map.add(1, "foo");

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "foo", .hash_value = 1 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(1, map.len);
}

test "add(value) inserts into bucket when value computes to probed bucket" {
    var map = try testMap(3);
    defer map.deinit();

    _ = try map.add(1, "bar");

    const ret = try map.add(4, "baz");

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "bar", .hash_value = 1 } },
            TestMap.Bucket { .full = .{ .key = 4, .value = "baz", .hash_value = 4 } },
        },
        map.buckets
    );
    try testing.expectEqual(2, map.len);
}

test "add(value) inserts into deleted bucket when value computes to probed bucket across deleted buckets" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(1, "a");
    _ = try map.add(2, "b");
    _ = try map.add(3, "c");
    _ = map.remove(2);

    const ret = try map.add(7, "d");

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "a", .hash_value = 1 } },
            TestMap.Bucket { .full = .{ .key = 7, .value = "d", .hash_value = 7 } },
            TestMap.Bucket { .full = .{ .key = 3, .value = "c", .hash_value = 3 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(3, map.len);
}

test "add(value) does not insert when value is present at head bucket" {
    var map = try testMap(3);
    defer map.deinit();

    _ = try map.add(1, "a");
    const ret = try map.add(1, "b");

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "a", .hash_value = 1 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(1, map.len);
}

test "add(value) does not insert when value is present at probed bucket" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(6, "six");
    _ = try map.add(1, "one");
    const ret = try map.add(1, "nope");

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 6, .value = "six", .hash_value = 6 } },
            TestMap.Bucket { .full = .{ .key = 1, .value = "one", .hash_value = 1 } },
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(2, map.len);
}

test "add(value) does not insert when value is present at probed bucket across deleted buckets" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(6, "6");
    _ = try map.add(1, "1");
    _ = try map.add(3, "3");
    _ = map.remove(1);

    const ret = try map.add(3, "3 again");

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 6, .value = "6", .hash_value = 6 } },
            TestMap.Bucket.deleted,
            TestMap.Bucket { .full = .{ .key = 3, .value = "3", .hash_value = 3 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(2, map.len);
}

test "add(value) rehashes when the load factor is crossed" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(2, "2");
    _ = try map.add(4, "4");
    _ = try map.add(7, "3 then 7");

    _ = try map.add(8, "8");

    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket {
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 2, .value = "2", .hash_value = 2 } },
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 4, .value = "4", .hash_value = 4 } },
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 7, .value = "3 then 7", .hash_value = 7 } },
            TestMap.Bucket { .full = .{ .key = 8, .value = "8", .hash_value = 8 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(4, map.len);
}

test "remove(value) marks the bucket as deleted when value present at head bucket" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(1, "a");
    const ret = map.remove(1);

    try testing.expect(ret != null);
    try testing.expectEqualSlices(u8, "a", ret.?);
    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket.deleted,
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(0, map.len);
}

test "remove(value) marks the bucket as deleted when value present at probed bucket" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(11, "11");
    _ = try map.add(6, "6");
    _ = try map.add(1, "1");

    const ret = map.remove(1);

    try testing.expectEqualSlices(u8, "1", ret.?);
    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 11, .value = "11", .hash_value = 11 } },
            TestMap.Bucket { .full = .{ .key = 6, .value = "6", .hash_value = 6 } },
            TestMap.Bucket.deleted,
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(2, map.len);
}

test "remove(value) returns null when value not present" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(1, "1");
    _ = try map.add(2, "2");
    _ = try map.add(3, "3");

    const ret = map.remove(4);

    try testing.expectEqual(null, ret);
    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "1", .hash_value = 1 } },
            TestMap.Bucket { .full = .{ .key = 2, .value = "2", .hash_value = 2 } },
            TestMap.Bucket { .full = .{ .key = 3, .value = "3", .hash_value = 3 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(3, map.len);
}

test "has(value) returns true when value is present" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(1, "1");
    _ = try map.add(2, "2");
    _ = try map.add(3, "3");

    try testing.expect(map.has(2));
}

test "has(value) returns false when value is not present" {
    var map = try testMap(5);
    defer map.deinit();

    _ = try map.add(1, "1");
    _ = try map.add(2, "2");
    _ = try map.add(3, "3");

    try testing.expect(!map.has(5));
}
