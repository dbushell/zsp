const std = @import("std");
const Context = @import("./Context.zig");
const Host = @import("./Host.zig");
const TTY = @import("./TTY.zig");
const assert = std.debug.assert;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    // const gpa_allocator = gpa.allocator();
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    var tty = TTY.init();

    var context = Context.init(allocator, std.fs.cwd());
    defer context.deinit();
    try context.scanAll();

    // Remove Node.js false positive
    // @TODO Handle multi-runtime projects, e.g. SvelteKit?
    if (context.is(.node)) {
        if (context.is(.bun) or context.is(.deno)) {
            _ = context.props.remove(.node);
        }
    }

    var host = Host{};

    try tty.color(.dim);
    try tty.print("{s}", .{host.user()});
    try tty.color(.reset);
    try tty.color(.bold);
    try tty.color(.green);
    try tty.print("@{s}", .{try host.name()});
    try tty.color(.reset);
    try tty.print(" {s}", .{host.emoji()});

    try context.print(&tty);

    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);

    try tty.color(.dim);
    try tty.print(" {s}\n", .{path});
    try tty.color(.reset);

    try tty.color(.blue);
    try tty.print("→ ", .{});

    try tty.color(.reset);
}
