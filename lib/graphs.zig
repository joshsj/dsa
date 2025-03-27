//! Very WIP

const std = @import("std");
const Allocator = std.mem.Allocator;

const testing = @import("testing.zig");
const common = @import("common.zig");

const HashMap = @import("hash-map.zig").HashMap;
const HashSet = @import("hash-set.zig").HashSet;
const Queue = @import("queue.zig").Queue;

fn Graph(comptime T: type) type { return HashMap(T, []T); }

const Weight = u32;
const Inf = std.math.maxInt(Weight);

fn WeightedEdge(comptime T: type) type { return struct { to: T, weight: Weight }; }
fn WeightedGraph(comptime T: type) type { return HashMap(T, []WeightedEdge(T)); }

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

fn nearest_unvisited(comptime T: type, dists: HashMap(T, Weight), visited: HashSet(T)) ?HashMap(T, Weight).Pair {
    var min_pair = HashMap(T, Weight).Pair { .key = undefined, .value = Inf };

    var iter = dists.iter();

    while (try iter.next()) |pair| {
        if (!visited.has(pair.key) and pair.value < min_pair.value) {
            min_pair = pair;
        }
    }

    return if (min_pair.value < Inf) min_pair else null;
}

fn dijkstra_no_heap(
    comptime T: type,
    graph: WeightedGraph(T),
    dists: *HashMap(T, Weight),
    origin: T
) !void {
    var visited = try HashSet(T).initCapacityLoadFactor(graph.allocator, graph.ctx, graph.len, 1);
    defer visited.deinit();

    {
        var iter = graph.iter();

        while (try iter.next()) |pair| {
            try dists.add(pair.key, Inf);
        }

        try dists.update(origin, 0);
    }

    while (nearest_unvisited(T, dists.*, visited)) |curr| {
        _ = try visited.add(curr.key);

        const edges = graph.get(curr.key) orelse continue;

        for (edges) |edge| {
            if (visited.has(edge.to)) {
                continue;
            }

            const dist = curr.value + edge.weight;

            if (dist < dists.get(edge.to).?) {
                try dists.update(edge.to, dist);
            }
        }
    }
}

test dijkstra_no_heap {
    const ctx = Graph(u8).Context { 
        .equal = common.defaultEqual(u8),
        .hash = common.coerced(u8, usize),
    };

    var graph = try WeightedGraph(u8).init(testing.allocator, ctx);
    defer graph.deinit();
    
    {
        var arr = [_]WeightedEdge(u8) {
            .{ .to = 1, .weight = 1, },
            .{ .to = 2, .weight = 5, },
        };
        try graph.add(0, &arr);
    }

    {
        var arr = [_]WeightedEdge(u8) {
            .{ .to = 2, .weight = 7, },
            .{ .to = 3, .weight = 3, },
        };
        try graph.add(1, &arr);
    }

    {
        var arr = [_]WeightedEdge(u8) {
            .{ .to = 4, .weight = 1, },
        };
        try graph.add(2, &arr);
    }

    {
        var arr = [_]WeightedEdge(u8) {
            .{ .to = 1, .weight = 1, },
            .{ .to = 2, .weight = 2, },
        };
        try graph.add(3, &arr);
    }

    { try graph.add(4, &[0]WeightedEdge(u8) {}); }

    var dists = try HashMap(u8, Weight).initCapacityLoadFactor(graph.allocator, graph.ctx, graph.len, 1);
    defer dists.deinit();

    try dijkstra_no_heap(u8, graph, &dists, 0);

    try testing.expectEqual(0, dists.get(0));
    try testing.expectEqual(1, dists.get(1));
    try testing.expectEqual(5, dists.get(2));
    try testing.expectEqual(4, dists.get(3));
    try testing.expectEqual(6, dists.get(4));
}

