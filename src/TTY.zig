const std = @import("std");
const Color = std.io.tty.Color;

const Self = @This();

writer: std.fs.File.Writer,
config: std.io.tty.Config,
/// Current ANSI style
color: Color = undefined,
/// Maximum prompt columns (visible utf8 characters)
utf8_max_len: usize,
/// Current prompt written (visible utf8 characters)
utf8_len: usize = 0,

pub fn init(columns: usize) Self {
    return .{
        .writer = std.io.getStdOut().writer(),
        .config = std.io.tty.detectConfig(std.io.getStdErr()),
        .utf8_max_len = columns,
    };
}

/// Number of characters left on first line
pub fn remaining(self: Self) usize {
    if (self.utf8_len >= self.utf8_max_len) return 0;
    return self.utf8_max_len - self.utf8_len;
}

/// Write string to prompt
pub fn write(self: *Self, bytes: []const u8) void {
    if (bytes.len == 0) return;
    // Count visible characters written
    self.utf8_len += std.unicode.utf8CountCodepoints(bytes) catch unreachable;
    _ = self.writer.write(bytes) catch return;
}

/// Write formatted string to prompt
pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
    if (format.len == 0) return;
    // Write to buffer and pass through `self.write`
    // This allows written characters to be counted
    var buf = [_]u8{0} ** 256;
    const slice = std.fmt.bufPrint(&buf, format, args) catch return;
    self.write(slice);
}

/// Set current prompt ASNI style
pub fn ansi(self: *Self, styles: []const Color) void {
    for (styles) |s| {
        if (self.color == s) continue;
        _ = self.writer.write("%{") catch return;
        self.config.setColor(self.writer, s) catch return;
        _ = self.writer.write("%}") catch return;
        self.color = s;
    }
}
