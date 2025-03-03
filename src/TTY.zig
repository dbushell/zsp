const std = @import("std");
const Color = std.io.tty.Color;

const TTY = @This();

writer: std.fs.File.Writer,
config: std.io.tty.Config,
current_color: Color = undefined,

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

pub fn color(self: *TTY, new_color: Color) !void {
    if (self.current_color == new_color) return;
    _ = try self.writer.write("%{");
    try self.config.setColor(self.writer, new_color);
    _ = try self.writer.write("%}");
    self.current_color = new_color;
}
