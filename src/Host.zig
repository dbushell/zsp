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

/// Returns the system hostname
pub fn name(self: *Host) ![]const u8 {
    const hostname = try posix.gethostname(&self.hostname_buffer);
    if (mem.indexOfScalar(u8, hostname, '.')) |i| {
        return hostname[0..i];
    }
    return hostname;
}

/// Returns an OS emoji
pub fn emoji(_: Host) []const u8 {
    return switch (builtin.os.tag) {
        .macos => "",
        .linux => emoji: {
            // @TODO Check uname for Raspberry Pi or Proxmox etc
            break :emoji "";
        },
        else => "",
    };
}
