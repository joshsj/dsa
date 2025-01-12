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

pub fn defaultCompare(comptime T: type) Compare(T) {
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
pub fn bubble(comptime T: type, comptime compare: Compare(T), items: []T) void {
    if (items.len <= 1) {
        return;
    }

    for (0..items.len) |i| {
        for (1..items.len - i) |j| {
            const pair = items[j - 1..][0..2];

            if (compare(pair[0], pair[1]) == .gt) {
                mem.swap(T, &pair[0], &pair[1]);
            }
        }
    }
}

/// Uses last item as the pivot value
/// O(n)
pub fn partition(comptime T: type, comptime compare: Compare(T), items: []T) ?usize {
    if (items.len == 0) {
        return null;
    }
    
    // Save some cycles
    if (items.len == 1) {
        return 0;
    }

    const pivot = items[items.len - 1];
    var l: ?usize = null;
    var r: usize = 0;

    while (r < items.len) : (r += 1) {
        // TODO including == is cleaner as the pivot will be the final swap
        // but it creates more swaps as any equal values will be swapper needlessly
        if (compare(items[r], pivot) != .gt) {
            l = if (l) |tmp| tmp + 1 else 0;

            mem.swap(T, &items[l.?], &items[r]);
        }
    }

    return l orelse r - 1;
}

pub fn quick(comptime T: type, comptime compare: Compare(T), items: []T) void {
    if (items.len <= 1) {
        return;
    }

    const pivot_idx = partition(T, compare, items).?;

    quick(T, compare, items[0..pivot_idx]);
    quick(T, compare, items[pivot_idx..items.len]);
}

const Str = []const u8;

// Zig needs LINQ or list comprehension - SOMETHING
fn sum(str: Str) usize {
    var ret: usize = 0;

    for (str) |i| { 
        ret += i;
    }

    return ret;
}

// Sum of chars in string
fn badCompare(a: Str, b: Str) Order {
    return defaultCompare(usize)(sum(a), sum(b));
}

test "given a sorted slice of i8 when bubble() then slice is unchanged" {
    var items = [_]i8 { 5, 10, };

    bubble(i8, defaultCompare(i8), &items);

    const expected = [_]i8 { 5, 10, };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given a sorted slice of i8 when bubble() then slice is sorted" {
    var items = [_]i8 { 10, 5 };

    bubble(i8, defaultCompare(i8), &items);

    const expected = [_]i8 { 5, 10, };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given an unsorted slice of i8 when bubble() then slice is sorted" {
    var items = [_]i8 { 10, 5, -2, 0, 7 };

    bubble(i8, defaultCompare(i8), &items);

    const expected = [_]i8 { -2, 0, 5, 7, 10 };

    try testing.expectEqualSlices(i8, &expected, &items);
}

test "given an unsorted slice of strings when bubble() then slice is sorted" {
    var items = [_]Str { "oof", "foo", "baz", "bar", };

    bubble(Str, badCompare, &items);

    // oof comes before foo because string have same sum
    // and swaps are only executed when l > r
    const expected = [_]Str { "bar", "baz", "oof", "foo", };

    try testing.expectEqualSlices(Str, &expected, &items);
}

test "given an empty slice when partition() then pivot index is null" {
    var items = [_]u8 {};

    const pivot_idx = partition(u8, defaultCompare(u8), &items);
    
    try testing.expectEqual(null, pivot_idx);
}

test "given a single-item slice when partition() then pivot index is 0" {
    var items = [_]u8 { 5 };

    const pivot_idx = partition(u8, defaultCompare(u8), &items);
    
    try testing.expectEqual(0, pivot_idx);
}

test "given an unsorted slice when partition() then correct pivot index is returned and items are partitioned around pivot" {
    var items = [_]u8 { 9, 4, 3, 7, 8, 2, 5 };

    const expected = [_]u8 { 4, 3, 2, 5, 8, 9, 7 };

    const pivot_idx = partition(u8, defaultCompare(u8), &items);

    try testing.expectEqual(3, pivot_idx);
    try testing.expectEqualSlices(u8, &expected, &items);
}

test "given a sorted slice when partition() then correct pivot index is returned and items are unchanged" {
    var items = [_]u8 { 1, 2, 3, 4, 5 };

    const expected = [_]u8 { 1, 2, 3, 4, 5 };

    const pivot_idx = partition(u8, defaultCompare(u8), &items);

    try testing.expectEqual(4, pivot_idx);
    try testing.expectEqualSlices(u8, &expected, &items);
}

test "given an unsorted slice of u8 when quick() then slice is sorted" {
    var items = [_]u8 { 9, 4, 3, 7, 8, 2, 5 };

    const expected = [_]u8 { 2, 3, 4, 5, 7, 8, 9, };

    quick(u8, defaultCompare(u8), &items);

    try testing.expectEqualSlices(u8, &expected, &items);
}

test "given a sorted slice of u8 when quick() then slice is unchanged" {
    var items = [_]u8 { 2, 3, 4, 5, 7, 8, 9, };

    const expected = [_]u8 { 2, 3, 4, 5, 7, 8, 9, };

    quick(u8, defaultCompare(u8), &items);

    try testing.expectEqualSlices(u8, &expected, &items);
}

test "given an unsorted slice of strings when quick() then slice is sorted" {
    var items = [_]Str { "foo", "oof", "baz", "bar", };

    quick(Str, badCompare, &items);

    // foo and oof are swapped only as a consequence of quick() logic
    const expected = [_]Str { "bar", "baz", "oof", "foo", };

    try testing.expectEqualSlices(Str, &expected, &items);
}

