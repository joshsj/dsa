pub fn Equal(comptime T: type) type {
    return fn(l: T, r: T) bool;
}

pub fn defaultEqual(comptime T: type) Equal(T) {
    return struct {
        fn f(l: T, r: T) bool {
            return l == r;
        }
    }.f;
}

