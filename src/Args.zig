const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMapUnmanaged;

pub const Tag = enum {
    bool,
    int,
    string,
};

pub const Value = union(Tag) {
    bool: bool,
    int: usize,
    string: []const u8,
};

const Self = @This();

allocator: Allocator,
items: StringHashMap(Value),

pub fn init(allocator: Allocator) !Self {
    var args = Self{
        .allocator = allocator,
        .items = .empty,
    };
    try args.processArgs();
    return args;
}

pub fn deinit(self: *Self) void {
    var keys = self.items.iterator();
    while (keys.next()) |entry| {
        if (entry.value_ptr.* == .string) {
            self.allocator.free(entry.value_ptr.string);
        }
        self.allocator.free(entry.key_ptr.*);
    }
    self.items.deinit(self.allocator);
    self.* = undefined;
}

fn processArgs(self: *Self) !void {
    var iter = std.process.args();
    while (iter.next()) |arg| {
        var key: []const u8 = arg;
        var value: Value = .{ .bool = true };
        // Trim flag prefix
        if (mem.startsWith(u8, key, "--")) {
            key = arg[2..];
        }
        // Get value as string
        if (mem.indexOfScalar(u8, key, '=')) |i| {
            if (i + 1 < key.len) value = .{ .string = key[i + 1 ..] };
            key = key[0..i];
        }
        // Parse boolean or integer values
        if (value == .string) parse: {
            // Empty string or "true" string is truthy
            if (value.string.len == 0 or mem.eql(u8, value.string, "true")) {
                value = .{ .bool = true };
                // "false" string is falsy
            } else if (mem.eql(u8, value.string, "false")) {
                value = .{ .bool = false };
            } else {
                // Parse string as integer
                for (value.string) |c| if (!std.ascii.isDigit(c)) break :parse;
                value = .{ .int = try std.fmt.parseInt(usize, value.string, 10) };
            }
        }
        if (value == .string) {
            value.string = try self.allocator.dupe(u8, value.string);
        }
        try self.items.put(
            self.allocator,
            try self.allocator.dupe(u8, key),
            value,
        );
    }
}
