const std = @import("std");
const testing = @import("testing.zig");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");

pub fn HashMap(comptime TKey: type, comptime TValue: type) type {
    return struct {
        const DefaultCapacity = 4; // Picked at random
        const LoadFactor: f16 = 0.75; // Stolen from the internet

        const Self = @This();
        const Iterator = @import("hash-map.iterator.zig").HashMapIterator(TKey, TValue);

        pub const Context = struct { 
            hash: *const common.Hash(TKey),
            equal: *const common.Equal(TKey),
        };

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

        /// O(1)
        pub fn add(self: *Self, key: TKey, value: TValue) (Allocator.Error || error{ KeyInUse })!void {
            const bucket_p, const hash_value =
                if (self.nextBucket(key)) |ret| blk: {
                    if (ret[0].* == .full) {
                        return error.KeyInUse;
                    }

                    break :blk
                        if (try self.rehashIfOverloaded(1)) self.nextBucket(key) orelse unreachable
                        else ret;
                } else blk: {
                    try self.rehash();

                    break :blk self.nextBucket(key) orelse unreachable;
                };

            std.debug.assert(bucket_p.* != .full);

            bucket_p.* = .{ .full = .{ .key = key, .value = value, .hash_value = hash_value } };
            self.len += 1;
        }

        /// Returns true if key was added, false if updated
        ///
        /// O(1)
        pub fn set(self: *Self, key: TKey, value: TValue) Allocator.Error!bool {
            // TODO: calls nextBucket in update and add but this is easier :shrug:
            return if (self.update(key, value)) false
                else |_| if (self.add(key, value)) true
                    else |err| switch (err) {
                        error.KeyInUse => unreachable,
                        else => |narrowed| narrowed
                    };
        }

        /// O(1)
        pub fn update(self: Self, key: TKey, value: TValue) error{ KeyNotFound }!void {
            const bucket_p, _ = self.nextBucket(key) orelse return error.KeyNotFound;

            switch (bucket_p.*) {
                .full => |*full| full.value = value,
                else => return error.KeyNotFound,
            }
        }

        /// O(1)
        pub fn remove(self: *Self, key: TKey) ?TValue {
            const bucket_p, _ = self.nextBucket(key) orelse return null;

            return switch (bucket_p.*) {
                .full => |full| {
                    bucket_p.* = .deleted;
                    self.len -= 1;
                    return full.value;
                },
                else => null,
            };
        }

        /// O(1)
        pub fn has(self: Self, key: TKey) bool {
            const bucket_p, _ = self.nextBucket(key) orelse return false;

            return bucket_p.* == .full;
        }

        pub fn iter(self: Self) Iterator {
            return Iterator.init(self);
        }

        fn rehashIfOverloaded(self: *Self, adding: usize) Allocator.Error!bool {
            // TODO: f64 is probably the wrong float for the job
            // but I don't know what would be :/
            const capacity: f64 = @floatFromInt(self.buckets.len);
            const max_load_for_capacity: usize = @intFromFloat(capacity * LoadFactor);

            return if (self.len + adding > max_load_for_capacity) {
                try self.rehash();
                return true;
            } else false;
        }

        /// O(n)
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

        /// Returns the full bucket containing the key
        /// or the first deleted/empty bucket
        fn nextBucket(self: Self, key: TKey) ?struct { *Bucket, usize } {
            const hash_value = self.ctx.hash(key);
            const head_i = hash_value % self.buckets.len;
            var probe_i: usize = 0;

            var first_deleted_p: ?*Bucket = null;

            while (probe_i < self.buckets.len) : (probe_i += 1) {
                const bucket_p = &self.buckets[(head_i + probe_i) % self.buckets.len];

                switch (bucket_p.*) {
                    .empty => return .{ first_deleted_p orelse bucket_p, hash_value },

                    .deleted => if (first_deleted_p == null) { first_deleted_p = bucket_p; },

                    .full => |full| {
                        if (full.hash_value == hash_value and self.ctx.equal(full.key, key)) {
                            return .{ bucket_p, hash_value };
                        }
                    }
                }
            }

            return
                if (first_deleted_p) |p| .{ p, hash_value }
                // Should not be null here: only happens when all buckets are full
                // and load factor management on add/set prevents this (touch wood)
                else null;
        }

        fn alloc(allocator: Allocator, len: usize) Allocator.Error![]Bucket {
            const buckets = try allocator.alloc(Bucket, len);
            @memset(buckets, Bucket.empty);
            return buckets;
        }
    };
}

const Str = [:0]const u8;
const TestMap = HashMap(usize, Str,);

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

    try map.add(1, "foo");

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

    try map.add(1, "bar");

    try map.add(4, "baz");

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

    try map.add(1, "a");
    try map.add(2, "b");
    try map.add(3, "c");
    _ = map.remove(2);

    try map.add(7, "d");

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

    try map.add(1, "a");
    const ret = map.add(1, "b");

    try testing.expectError(error.KeyInUse, ret);
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

    try map.add(6, "six");
    try map.add(1, "one");

    const ret = map.add(1, "nope");

    try testing.expectError(error.KeyInUse, ret);
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

    try map.add(6, "6");
    try map.add(1, "1");
    try map.add(3, "3");
    _ = map.remove(1);

    const ret = map.add(3, "3 again");

    try testing.expectError(error.KeyInUse, ret);
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

test "add(value) does not rehash when value is present" {
    var map = try testMap(5);
    defer map.deinit();

    try map.add(2, "2");
    try map.add(4, "4");
    try map.add(7, "7");

    const ret = map.add(2, "dupe");

    try testing.expectError(error.KeyInUse, ret);
    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket {
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 2, .value = "2", .hash_value = 2 } },
            TestMap.Bucket { .full = .{ .key = 7, .value = "7", .hash_value = 7 } },
            TestMap.Bucket { .full = .{ .key = 4, .value = "4", .hash_value = 4 } },
        },
        map.buckets
    );
    try testing.expectEqual(3, map.len);
}

test "add(value) rehashes when value is not present and load factor is met" {
    var map = try testMap(5);
    defer map.deinit();

    try map.add(2, "2");
    try map.add(4, "4");
    try map.add(7, "3 then 7");

    try map.add(8, "8");

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

test "update(value) updates the bucket value when value present" {
    var map = try testMap(3);
    defer map.deinit();

    try map.add(1, "old");

    try map.update(1, "new");

    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "new", .hash_value = 1 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(1, map.len);
}

test "update(value) returns an error when value not present" {
    var map = try testMap(3);
    defer map.deinit();

    const err = map.update(1, "new");

    try testing.expectError(
        error.KeyNotFound,
        err,
    );
}

test "set(value) updates the bucket value when value present" {
    var map = try testMap(3);
    defer map.deinit();

    try map.add(1, "old");

    const ret = try map.set(1, "new");

    try testing.expect(!ret);
    try testing.expectEqualSlices(
        TestMap.Bucket,
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 1, .value = "new", .hash_value = 1 } },
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(1, map.len);
}

test "set(value) inserts into bucket when value is not present" {
    var map = try testMap(5);
    defer map.deinit();

    try map.add(6, "six");

    const ret = try map.set(1, "juan");

    try testing.expect(ret);
    try testing.expectEqualSlices(
        TestMap.Bucket, 
        &[_]TestMap.Bucket { 
            TestMap.Bucket.empty,
            TestMap.Bucket { .full = .{ .key = 6, .value = "six", .hash_value = 6 } },
            TestMap.Bucket { .full = .{ .key = 1, .value = "juan", .hash_value = 1 } },
            TestMap.Bucket.empty,
            TestMap.Bucket.empty,
        },
        map.buckets
    );
    try testing.expectEqual(2, map.len);
}

test "remove(value) marks the bucket as deleted when value present at head bucket" {
    var map = try testMap(5);
    defer map.deinit();

    try map.add(1, "a");
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

    try map.add(11, "11");
    try map.add(6, "6");
    try map.add(1, "1");

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

    try map.add(1, "1");
    try map.add(2, "2");
    try map.add(3, "3");

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

    try map.add(1, "1");
    try map.add(2, "2");
    try map.add(3, "3");

    try testing.expect(map.has(2));
}

test "has(value) returns false when value is not present" {
    var map = try testMap(5);
    defer map.deinit();

    try map.add(1, "1");
    try map.add(2, "2");
    try map.add(3, "3");

    try testing.expect(!map.has(5));
}
