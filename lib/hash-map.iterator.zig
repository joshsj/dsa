const std = @import("std");
const testing = @import("testing.zig");

const common = @import("common.zig");
const HashMap = @import("hash-map.zig").HashMap;

pub fn HashMapIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        
        buckets: []const HashMap(T).Bucket,
        moved: bool = false,

        pub fn init(map: HashMap(T)) Self {
            return Self { .buckets = map.buckets };
        }

        pub fn curr(self: Self) ?T {
            return if (self.moved and self.buckets.len > 0) self.buckets[0].full.value
                   else null;
        }
        
        pub fn next(self: *Self) !?T {
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
    var map = try HashMap(usize).initCapacity(
        testing.allocator,
        HashMap(usize).Context {
            .equal = common.defaultEqual(usize),
            .hash = common.identity(usize),
        },
        5
    );
    defer map.deinit();

    _ = try map.add(0);
    // 1 empty
    _ = try map.add(2);
    _ = try map.add(3);
    _ = try map.add(4);

    _ = map.remove(3);

    const expected = &[_]usize { 0, 2, 4 };

    try testing.expectEqualSliceToIter(
        usize,
        expected,
        HashMapIterator(usize).init(map),
    );
}
