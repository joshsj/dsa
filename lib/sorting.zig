const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const math = std.math;
const Order = math.Order;

// TODO std lib passes the items as a 'context'
// to these kind of functions - why?
fn Compare(comptime T: type) type {
    return fn (l: T, r: T) Order;
}

pub fn compare(comptime T: type) Compare(T) {
    return struct {
        fn f(l: T, r: T) Order {
            if (l > r) {
                return .gt;
            } 

            if (l < r) {
                return .lt;
            }

            // TODO check equality explicitly?
            // shouldn't be needed but idk zig
            // well enough to know of any edge cases
            // (i'm looking at you, floats)
            return .eq;
        }
    }.f;
}

/// O(n^2)
pub fn bubble(comptime T: type, comptime compare_fn: Compare(T), items: []T) void {
    if (items.len <= 1) {
        return;
    }

    for (0..items.len) |i| {
        for (1..items.len - i) |j| {
            const pair = items[j - 1..][0..2];

            if (compare_fn(pair[0], pair[1]) == .gt) {
                mem.swap(T, &pair[0], &pair[1]);
            }
        }
    }
}

test "given a slice of 2 ints in order when bubbleSort() then slice is unchanged" {
    var items = [_]i8 { 5, 10, };

    bubble(i8, compare(i8), &items);

    const expected = [_]i8 { 5, 10, };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given a slice of 2 ints out of order when bubbleSort() then slice is ordered" {
    var items = [_]i8 { 10, 5 };

    bubble(i8, compare(i8), &items);

    const expected = [_]i8 { 5, 10, };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given a slice of 5 ints out of order when bubbleSort() then slice is ordered" {
    var items = [_]i8 { 10, 5, -2, 0, 7 };

    bubble(i8, compare(i8), &items);

    const expected = [_]i8 { -2, 0, 5, 7, 10 };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given a slice of 5 strings out of order when bubbleSort() then slice is ordered" {
    const Str = []const u8;

    // Zig needs LINQ or list comprehension - SOMETHING
    const sum = struct {
        fn f(str: Str) usize {
            var sum: usize = 0;

            for (str) |c| {
                sum += c;
            }

            return sum;
        }
    }.f;

    // Sum of chars in string
    const bad_compare_fn = struct {
        fn f(a: Str, b: Str) Order {
            return compare(usize)(sum(a), sum(b));
        }
    }.f;

    var items = [_]Str { "oof", "foo", "baz", "bar", };

    bubble(Str, bad_compare_fn, &items);

    // oof comes before foo because string have same sum
    // and swaps are only executed when l > r
    const expected = [_]Str { "bar", "baz", "oof", "foo", };

    try testing.expectEqualSlices(Str, &expected, &items);
}

