const std = @import("std");
const testing = @import("testing.zig");

const common = @import("common.zig");
const HashMap = @import("hash-map.zig").HashMap;

pub fn HashMapIterator(comptime TKey: type, comptime TValue: type) type {
    return struct {
        const Self = @This();
        const Pair = HashMap(TKey, TValue).Pair;
        
        buckets: []const HashMap(TKey, TValue).Bucket,
        moved: bool = false,

        pub fn init(map: HashMap(TKey, TValue)) Self {
            return Self { .buckets = map.buckets };
        }

        pub fn curr(self: Self) ?Pair {
            const bucket =
                if (self.moved and self.buckets.len > 0) self.buckets[0].full
                else return null;

            return .{ .key = bucket.key, .value = bucket.value, };
        }
        
        pub fn next(self: *Self) !?Pair {
            if (self.moved) {
                self.buckets =
                    if (self.buckets.len > 0) self.buckets[1..] 
                    else return null;
            } else {
                self.moved = true;
            }

            while (self.buckets.len > 0 and self.buckets[0] != .full) {
                self.buckets = self.buckets[1..];
            }

            return self.curr();
        }
    };
}

test HashMapIterator {
    const Str = [:0]const u8;

    var map = try HashMap(usize, Str).initCapacity(
        testing.allocator,
        .{
            .equal = common.defaultEqual(usize),
            .hash = common.identity(usize),
        },
        5
    );
    defer map.deinit();

    _ = try map.add(0, "0");
    // 1 empty
    _ = try map.add(2, "2");
    _ = try map.add(3, "3");
    _ = try map.add(4, "4");

    _ = map.remove(3);

    const expected = &[_]HashMap(usize, Str).Pair {
        .{ .key = 0, .value = "0" },
        .{ .key = 2, .value = "2" },
        .{ .key = 4, .value = "4" },
    };

    try testing.expectEqualSliceToIter(
        HashMap(usize, Str).Pair,
        expected,
        HashMapIterator(usize, Str).init(map),
    );
}
