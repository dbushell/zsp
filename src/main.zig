const std = @import("std");
const builtin = @import("builtin");
const Context = @import("./Context.zig");
const Host = @import("./Host.zig");
const TTY = @import("./TTY.zig");
const Allocator = std.mem.Allocator;
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

    const tty = TTY.init();

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

    try tty.setColor(.dim);
    try tty.print("{s}", .{host.user()});
    try tty.setColor(.reset);
    try tty.setColor(.bold);
    try tty.setColor(.green);
    try tty.print("@{s}", .{try host.name()});
    try tty.setColor(.reset);
    try tty.print(" {s}", .{host.emoji()});

    try context.print(tty);

    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);

    try tty.setColor(.dim);
    try tty.print(" {s}\n", .{path});
    try tty.setColor(.reset);

    try tty.setColor(.blue);
    try tty.print("→ ", .{});

    try tty.setColor(.reset);
}
