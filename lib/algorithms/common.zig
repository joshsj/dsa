const std = @import("std");
const Order = std.math.Order;

// TODO std lib passes the items as a 'context'
// to these kind of functions - why?
pub fn Compare(comptime T: type) type {
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

            return .eq;
        }
    }.f;
}

