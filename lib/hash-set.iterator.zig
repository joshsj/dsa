const std = @import("std");
const testing = @import("testing.zig");

const common = @import("common.zig");
const HashSet = @import("hash-set.zig").HashSet;

pub fn HashSetIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        
        buckets: []const HashSet(T).Bucket,
        moved: bool = false,

        pub fn init(set: HashSet(T)) Self {
            return Self { .buckets = set.buckets };
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

test HashSetIterator {
    var set = try HashSet(usize).initCapacity(
        testing.allocator,
        HashSet(usize).Context {
            .equal = common.defaultEqual(usize),
            .hash = common.identity(usize),
        },
        5
    );
    defer set.deinit();

    _ = try set.add(0);
    // 1 empty
    _ = try set.add(2);
    _ = try set.add(3);
    _ = try set.add(4);

    _ = set.remove(3);

    const expected = &[_]usize { 0, 2, 4 };

    try testing.expectEqualSliceToIter(
        usize,
        expected,
        HashSetIterator(usize).init(set),
    );
}
