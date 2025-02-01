const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

const Heap = @import("./heap.zig").Heap;
const ArrayList = @import("./array-list.zig").ArrayList;

const common = @import("../common.zig");

// TODO: kinda cool but we're 3 structures deep here lol
pub fn PriorityQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            priority: usize,
            value: T,

            fn compare(l: *Entry, r: *Entry) common.CompareOrder {
                return common.defaultCompare(usize)(l.priority, r.priority);
            }
        };

        allocator: Allocator,
        items: Heap(*Entry),

        pub fn init(allocator: Allocator) Allocator.Error!Self {
            return Self {
                .allocator = allocator,
                .items = try Heap(*Entry).initCompare(allocator, .max, &Entry.compare),
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.items.remove()) |entry| {
                self.allocator.destroy(entry);
            }

            self.items.deinit();
        }

        pub fn enqueue(self: *Self, priority: usize, value: T) Allocator.Error!void {
            var entry = try self.allocator.create(Entry);
            errdefer self.allocator.destroy(entry);

            entry.priority = priority;
            entry.value = value;

            try self.items.add(entry);
        }

        // TODO: return priority as well?
        pub fn deque(self: *Self) ?T {
            const entry = self.items.remove() orelse return null;
            defer self.allocator.destroy(entry);
            return entry.value;
        }
    };
}

test PriorityQueue {
    var queue = try PriorityQueue(u8).init(testing.allocator);
    defer queue.deinit();

    try queue.enqueue(3, 'b');
    try queue.enqueue(1, 'u');
    try queue.enqueue(0, 'h');
    try queue.enqueue(2, 'r');

    try testing.expectEqual('b', queue.deque());
    try testing.expectEqual('r', queue.deque());
    try testing.expectEqual('u', queue.deque());
    try testing.expectEqual('h', queue.deque());
    try testing.expectEqual(null, queue.deque());
}

