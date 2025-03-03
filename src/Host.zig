const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const posix = std.posix;

const Host = @This();

hostname_buffer: [std.posix.HOST_NAME_MAX]u8 = [_]u8{0} ** std.posix.HOST_NAME_MAX,

/// Returns the logged in username
pub fn user(_: Host) []const u8 {
    const maybe = posix.getenv("USER");
    return if (maybe) |string| string else "user";
}

/// Returns `true` for remote sessions
pub fn ssh(_: Host) bool {
    const maybe = posix.getenv("SSH_CONNECTION");
    return if (maybe) |_| true else false;
}

/// Returns the system hostname
pub fn name(self: *Host) ![]const u8 {
    const hostname = try posix.gethostname(&self.hostname_buffer);
    if (mem.indexOfScalar(u8, hostname, '.')) |i| {
        return hostname[0..i];
    }
    return hostname;
}

/// Returns the device model
pub fn model(_: Host) ?[]const u8 {
    const file = std.fs.openFileAbsolute(
        "/sys/firmware/devicetree/base/model",
        .{ .mode = .read_only },
    ) catch return null;
    var buf = [_]u8{0} ** 64;
    const size = file.read(&buf) catch return null;
    return if (size > 1) buf[0..size] else null;
}

/// Returns an OS emoji
pub fn emoji(self: Host) []const u8 {
    return switch (builtin.os.tag) {
        .macos => "",
        .linux => emoji: {
            if (self.model()) |string| {
                if (mem.indexOf(u8, string, "Raspberry Pi")) |_| break :emoji "";
            }
            break :emoji "";
        },
        else => "󱁣",
    };
}
