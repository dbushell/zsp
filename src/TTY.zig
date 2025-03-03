const std = @import("std");
const posix = std.posix;
const Color = std.io.tty.Color;

const TTY = @This();

writer: std.fs.File.Writer,
config: std.io.tty.Config,
current_color: Color = undefined,
utf8_max_len: usize = undefined,
utf8_len: usize = 0,

pub fn init(columns: usize) TTY {
    return .{
        .writer = std.io.getStdOut().writer(),
        .config = std.io.tty.detectConfig(std.io.getStdErr()),
        .utf8_max_len = columns,
    };
}

/// Number of characters left on first line of prompt
pub fn remaining(self: TTY) usize {
    if (self.utf8_len >= self.utf8_max_len) return 0;
    return self.utf8_max_len - self.utf8_len;
}

pub fn write(self: *TTY, bytes: []const u8) !void {
    self.utf8_len += try std.unicode.utf8CountCodepoints(bytes);
    _ = try self.writer.write(bytes);
}

pub fn print(self: *TTY, comptime format: []const u8, args: anytype) !void {
    // try self.writer.print(format, args);
    // try std.fmt.format(self.writer, format, args);
    var buf = [_]u8{0} ** 512;
    const slice = try std.fmt.bufPrint(&buf, format, args);
    try self.write(slice);
}

pub fn color(self: *TTY, new_color: Color) !void {
    if (self.current_color == new_color) return;
    _ = try self.writer.write("%{");
    try self.config.setColor(self.writer, new_color);
    _ = try self.writer.write("%}");
    self.current_color = new_color;
}
