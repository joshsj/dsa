const std = @import("std");
const Allocator = std.mem.Allocator;

const SinglyLinkedList = @import("singly-linked-list.zig").SinglyLinkedList;

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        items: SinglyLinkedList(T),

        pub fn init(allocator: Allocator) Self {
            return Self { .items = SinglyLinkedList(T).init(allocator), };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit();
        }

        pub fn push(self: *Self, value: T) Allocator.Error!void {
            try self.items.addFirst(value);
        }

        pub fn pop(self: *Self) ?T {
            return self.items.removeFirst();
        }

        pub fn peek(self: Self) ?T {
            return if (self.items.head) |head| head.value else null;
        }
    };
}

