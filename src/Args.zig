const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

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

const ArgsMap = std.StringHashMap(Value);

const Args = @This();

allocator: Allocator,
items: ArgsMap,

pub fn init(allocator: Allocator) !Args {
    var args = Args{
        .allocator = allocator,
        .items = ArgsMap.init(allocator),
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
        switch (value) {
            .string => |string| parse: {
                // Empty string or "true" string is truthy
                if (string.len == 0 or mem.eql(u8, string, "true")) {
                    value = .{ .bool = true };
                    // "false" string is falsy
                } else if (mem.eql(u8, string, "false")) {
                    value = .{ .bool = false };
                } else {
                    // Parse string as integer
                    for (string) |c| if (!std.ascii.isDigit(c)) break :parse;
                    value = .{ .int = try std.fmt.parseInt(usize, string, 10) };
                }
            },
            else => {},
        }
        try args.items.put(key, value);
    }
    return args;
}

pub fn deinit(self: *Args) void {
    self.items.deinit();
}
