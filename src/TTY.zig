const std = @import("std");

const TTY = @This();

writer: std.fs.File.Writer,
config: std.io.tty.Config,

pub fn init() TTY {
    return .{
        .writer = std.io.getStdOut().writer(),
        .config = std.io.tty.detectConfig(std.io.getStdErr()),
    };
}

pub fn write(self: TTY, bytes: []const u8) !void {
    _ = try self.writer.write(bytes);
}

pub fn print(self: TTY, comptime format: []const u8, args: anytype) !void {
    try self.writer.print(format, args);
}

pub fn setColor(self: TTY, color: std.io.tty.Color) !void {
    _ = try self.writer.write("%{");
    try self.config.setColor(self.writer, color);
    _ = try self.writer.write("%}");
}
