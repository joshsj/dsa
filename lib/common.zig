pub usingnamespace @import("common/compare.zig");
pub usingnamespace @import("common/equal.zig");
pub usingnamespace @import("common/hash.zig");
pub usingnamespace @import("common/slice-iterator.zig");
pub usingnamespace @import("common/slice-search.zig");
pub usingnamespace @import("common/slice-sort.zig");

pub fn identity(comptime T: type) fn(T) T {
    return struct {
        fn f(t: T) T {
            return t;
        }
    }.f;
}

pub fn coerced(comptime TValue: type, comptime TCoerced: type) fn(TValue) TCoerced {
    return struct {
        fn f(value: TValue) TCoerced {
            return value;
        }
    }.f;
}
