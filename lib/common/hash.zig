pub fn Hash(comptime T: type) type {
    return fn(value: T) usize;
}
