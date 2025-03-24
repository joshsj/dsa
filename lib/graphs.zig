//! Very WIP

const std = @import("std");

const testing = @import("testing.zig");
const common = @import("common.zig");

const HashMap = @import("hash-map.zig").HashMap;
const HashSet = @import("hash-set.zig").HashSet;
const Queue = @import("queue.zig").Queue;

fn Graph(comptime T: type) type { return HashMap(T, []T); }

fn bfs(comptime T: type, graph: Graph(T), origin: T, needle: T) std.mem.Allocator.Error!bool {
    if (graph.ctx.equal(origin, needle)) {
        return true;
    }

    var q = Queue(T).init(graph.allocator);
    defer q.deinit();

    var seen = try HashSet(T).init(graph.allocator, graph.ctx);
    defer seen.deinit();

    try q.enqueue(origin);
    try seen.add(origin);

    while (q.deque()) |curr| {
        if (graph.ctx.equal(curr, needle)) {
            return true;
        }

        if (!try seen.add(curr)) {
            continue;
        }

        if (graph.get(curr)) |adjacents| {
            for (adjacents) |adj| {
                try q.enqueue(adj);
            }
        }
    }

    return false;
}

test bfs {
    const ctx = Graph(u8).Context { 
        .equal = common.defaultEqual(u8),
        .hash = common.coerced(u8, usize),
    };

    var graph = try Graph(u8).init(testing.allocator, ctx);
    defer graph.deinit();

    {
        var arr = [_]u8 { 'b', 'd', };
        try graph.add('a', &arr);
    }

    {
        var arr = [_]u8 { 'd' };
        try graph.add('b', &arr);
    }

    {
        var arr = [_]u8 { 'a' };
        try graph.add('c', &arr);
    }

    {
        var arr = [_]u8 { 'c' };
        try graph.add('d', &arr);
    }

    const origin = 'a';

    try testing.expect(try bfs(u8, graph, origin, 'b'));
    try testing.expect(!try bfs(u8, graph, origin, 'z'));
}

