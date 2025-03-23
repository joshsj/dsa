pub fn Hash(comptime T: type) type {
    // TODO: is usize the right type?
    // not sure, it's a skill issue
    return fn(value: T) usize;
}
