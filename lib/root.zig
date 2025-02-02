test {
    // Not great...
    _ = @import("array-list.zig");

    _ = @import("common.zig");

    _ = @import("singly-linked-list.zig");
    _ = @import("singly-linked-list.iterator.zig");

    _ = @import("doubly-linked-list.zig");
    _ = @import("doubly-linked-list.iterator.zig");

    _ = @import("queue.zig");
    _ = @import("stack.zig");

    _ = @import("tests/list-adt.zig");

    // TODO: refactor the following
    _ = @import("algorithms/slice/sort.zig");
    _ = @import("algorithms/slice/search.zig");

    _ = @import("algorithms/tree/iterator.zig");
    _ = @import("algorithms/tree/search.zig");

    _ = @import("structures/binary-node.zig");
    _ = @import("structures/binary-search-tree.zig");

    _ = @import("structures/heap.zig");

}
