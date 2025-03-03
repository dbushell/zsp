const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

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

const Args = @This();

allocator: Allocator,
items: StringHashMap(Value),

pub fn init(allocator: Allocator) !Args {
    var args = Args{
        .allocator = allocator,
        .items = StringHashMap(Value).init(allocator),
    };
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
        try args.items.put(
            try allocator.dupe(u8, key),
            value,
        );
    }
    return args;
}

pub fn deinit(self: *Args) void {
    var keys = self.items.keyIterator();
    while (keys.next()) |k| self.allocator.free(k.*);
    self.items.deinit();
}
