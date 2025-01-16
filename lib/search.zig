const std = @import("std");
const testing = std.testing;
const sort = @import("sort.zig");
const Order = std.math.Order;

fn Compare(comptime T: type) type {
    return fn (l: T, r: T) Order;
}

// TODO: DRY
pub fn defaultCompare(comptime T: type) Compare(T) {
    return struct {
        fn f(l: T, r: T) Order {
            if (l > r) {
                return .gt;
            } 

            if (l < r) {
                return .lt;
            }

            return .eq;
        }
    }.f;
}

/// O(log(n))
pub fn binary(
    comptime T: type,
    compare: *const Compare(T),
    haystack: []const T,
    needle: T
) !?usize {
    if (haystack.len == 0) {
        return null;
    }

    var lo: usize = 0;
    var hi: usize = haystack.len - 1;

    while (lo <= hi) {
        const mid = lo + (hi - lo) / 2;
        const order = compare(haystack[mid], needle);

        if (order == .eq) {
            return mid;
        }

        // Could do this with slices and recursion (see quick)
        // but this approach is more transferable
        if (order == .gt) {
            // Prevent underflow
            hi = if (mid > 0) mid - 1 else return null;
        } else {
            lo = mid + 1;
        }
    }

    return null;
}

test "given no items when binary() then returns null" {
    const items = &[0]u8{};

    try testing.expectEqual(null, binary(u8, &defaultCompare(u8), items, 3));
}

test "given some items when binary(exists) then returns index" {
    var items = [_]u8{ 4, 7, 6, 3, 6, 5, 2, 8, 6, 9, 5};

    sort.quick(u8, &defaultCompare(u8), &items);

    try testing.expectEqual(2, binary(u8, &defaultCompare(u8), &items, 4));
}

test "given some items when binary(not exists) then returns index" {
    var items = [_]u8{ 4, 7, 6, 3, 6, 5, 2, 8, 6, 9, 5};

    sort.quick(u8, &defaultCompare(u8), &items);

    try testing.expectEqual(null, binary(u8, &defaultCompare(u8), &items, 1));
}

