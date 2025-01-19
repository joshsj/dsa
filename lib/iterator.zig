const std = @import("std");
const testing = std.testing;

pub fn SliceIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []const T,
        moved: bool = false,

        pub fn new(slice: []const T) Self {
            return Self { .slice = slice };
        }

        pub fn curr(self: Self) ?T {
            return if (self.slice.len > 0 and self.moved) self.slice[0] else null;
        }

        pub fn next(self: *Self) ?T {
            if (self.moved) {
                self.slice = self.slice[1..];
            } else {
                self.moved = true;
            }

            return self.curr();
        }
    };
}

test "given empty slice when curr() then null is returned" {
    const slice = &[0]u8 {};
    var iterator = SliceIterator(u8).new(slice);

    try testing.expectEqual(null, iterator.curr());
}

test "given empty slice when next() then null is returned" {
    const slice = &[0]u8 {};
    var iterator = SliceIterator(u8).new(slice);

    try testing.expectEqual(null, iterator.curr());
}

test "given slice of 1 item when curr() then returns null" {
    const slice = [_]u8 { 7, };
    var iterator = SliceIterator(u8).new(&slice);

    try testing.expectEqual(null, iterator.curr());
}

test "given slice of 1 item when next() then iterator moves through slice" {
    const slice = [_]u8 { 7, };
    var iterator = SliceIterator(u8).new(&slice);

    try testing.expectEqual(7, iterator.next());
    try testing.expectEqual(7, iterator.curr());

    try testing.expectEqual(null, iterator.next());
    try testing.expectEqual(null, iterator.curr());
}

test "given slice of many items when next() then iterator moves through slice" {
    const slice = [_]u8 { 7, 9 };
    var iterator = SliceIterator(u8).new(&slice);

    try testing.expectEqual(7, iterator.next());
    try testing.expectEqual(7, iterator.curr());

    try testing.expectEqual(9, iterator.next());
    try testing.expectEqual(9, iterator.curr());

    try testing.expectEqual(null, iterator.next());
    try testing.expectEqual(null, iterator.curr());
}
