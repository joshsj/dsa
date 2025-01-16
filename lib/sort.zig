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
pub fn bubble(comptime T: type, compare: *const Compare(T), items: []T) void {
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
pub fn partition(comptime T: type, compare: *const Compare(T), items: []T) ?usize {
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
        if (compare(items[r], pivot) != .gt) {
            l = if (l) |tmp| tmp + 1 else 0;

            mem.swap(T, &items[l.?], &items[r]);
        }
    }

    return l orelse r - 1;
}

/// O(n*log(n))
/// partition() is O(n)
/// quick calls partition log(n) times
pub fn quick(comptime T: type, compare: *const Compare(T), items: []T) void {
    if (items.len <= 1) {
        return;
    }

    const pivot_idx = partition(T, compare, items).?;

    quick(T, compare, items[0..pivot_idx]);
    quick(T, compare, items[pivot_idx..items.len]);
}

/// O(n^2)
pub fn selection(comptime T: type, compare: *const Compare(T), items: []T) void {
   if (items.len <= 1) {
        return;
    }

    for (0..items.len) |i| {
        var smallest_idx = i;

        for (i + 1..items.len) |j| {
            if (compare(items[j], items[smallest_idx]) == .lt) {
                smallest_idx = j;
            }
        }

        if (smallest_idx != i) {
            mem.swap(T, &items[i], &items[smallest_idx]);
        }
    }
}

const Str = []const u8;

fn compareStrings(a: Str, b: Str) Order {
    for (a, b) |char_a, char_b| {
        if (char_a > char_b) {
            return .gt;
        }

        if (char_a < char_b) {
            return .lt;
        }
    }

    return .eq;
}

fn test_u8s(sort: fn([]u8, *const Compare(u8)) void) !void {
    var no_items = [0]u8 {};
    sort(&no_items, &defaultCompare(u8));
    try testing.expectEqualSlices(u8, &[_]u8 {}, &no_items);

    var one_item = [_]u8 { 4, };
    sort(&one_item, &defaultCompare(u8));
    try testing.expectEqualSlices(u8, &[_]u8 { 4, }, &one_item);

    var some_items = [_]u8 { 5, 3, 4, 7, 6, 8, 1, 9, 2, 0, };
    sort(&some_items, &defaultCompare(u8));
    try testing.expectEqualSlices(u8, &[_]u8 { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, }, &some_items);
}

fn test_strs(sort: fn([]Str, *const Compare(Str)) void) !void {
    var items = [_]Str { "baz", "foo", "oof", "bar", };
    sort(&items, &compareStrings);
    try testing.expectEqualSlices(Str, &[_]Str { "bar", "baz", "foo", "oof", }, &items);
}

test bubble {
    try test_u8s(struct {
        fn f(data: []u8, compare: *const Compare(u8)) void {
            bubble(u8, compare, data);
        }
    }.f);

    try test_strs(struct {
        fn f(data: []Str, compare: *const Compare(Str)) void {
            bubble(Str, compare, data);
        }
    }.f);
}

test quick {
    try test_u8s(struct {
        fn f(data: []u8, compare: *const Compare(u8)) void {
            quick(u8, compare, data);
        }
    }.f);

    try test_strs(struct {
        fn f(data: []Str, compare: *const Compare(Str)) void {
            quick(Str, compare, data);
        }
    }.f);
}

test selection {
    try test_u8s(struct {
        fn f(data: []u8, compare: *const Compare(u8)) void {
            selection(u8, compare, data);
        }
    }.f);

    try test_strs(struct {
        fn f(data: []Str, compare: *const Compare(Str)) void {
            selection(Str, compare, data);
        }
    }.f);
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

