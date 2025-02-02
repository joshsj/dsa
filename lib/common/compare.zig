const std = @import("std");
pub const CompareOrder = std.math.Order;

// TODO: std lib passes the items as a 'context'
// to these kind of functions - why?
//
// ...cos Zig doesn't have closures!
pub fn Compare(comptime T: type) type {
    return fn (l: T, r: T) CompareOrder;
}

pub fn defaultCompare(comptime T: type) Compare(T) {
    return struct {
        fn f(l: T, r: T) CompareOrder {
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

