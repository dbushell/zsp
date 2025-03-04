const std = @import("std");
const Args = @import("./Args.zig");
const Context = @import("./Context.zig");
const Host = @import("./Host.zig");
const TTY = @import("./TTY.zig");
const assert = std.debug.assert;

const default_columns: usize = 80;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // const gpa_allocator = gpa.allocator();
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    var args = try Args.init(allocator);
    defer args.deinit();

    if (!args.items.contains("prompt")) return;

    const columns: usize = if (args.items.get("columns")) |entry| value: {
        break :value entry.int;
    } else default_columns;

    var tty = TTY.init(columns);

    var context = Context.init(allocator, std.fs.cwd());
    defer context.deinit();
    try context.scanAll();

    var host = Host{};

    try tty.write("\n");
    try tty.color(.dim);
    try tty.print("{s}", .{host.user()});
    try tty.color(.reset);
    try tty.color(.green);
    try tty.print("@{s}", .{try host.name()});
    try tty.color(.reset);
    try tty.print(" {s}", .{host.emoji()});

    try context.print(&tty);

    // Use remaining space for current path
    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);
    var cwd: []const u8 = path;
    var cwd_home = false;
    if (host.home()) |home| {
        if (std.mem.startsWith(u8, path, home)) {
            cwd = path[home.len..];
            cwd_home = true;
        }
    }
    try tty.color(.dim);
    try tty.write(" ");
    if (cwd_home) try tty.write("~");
    if (cwd.len < tty.remaining()) {
        try tty.print("{s}", .{cwd});
    } else if (tty.remaining() > 10) {
        try tty.print("{s}…", .{cwd[0 .. tty.remaining() - 1]});
    }
    try tty.color(.reset);

    // New line for input command
    try tty.color(.cyan);
    try tty.color(.bold);
    try tty.write("\n");
    if (host.ssh()) try tty.write("SSH ");
    try tty.print("→ ", .{});
    try tty.color(.reset);
}
