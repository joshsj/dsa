const std = @import("std");
const testing = std.testing;

// TODO: not sure if this is a smart pattern
// see https://github.com/ziglang/zig/issues/20663
pub usingnamespace testing;

pub fn expectEqualSliceToIter(
    comptime T: type,
    expected: []const T,
    actual: anytype
) !void {
    var iter = actual;

    try testing.expectEqual(false, actual.moved);

    for (expected) |expectedValue| {
        try testing.expectEqual(expectedValue, try iter.next());
        try testing.expectEqual(expectedValue, iter.curr());
    }

    try testing.expectEqual(null, try iter.next());
    try testing.expectEqual(null, iter.curr());
}
