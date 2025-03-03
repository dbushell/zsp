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
    try tty.color(.green);
    try tty.print("@{s}", .{try host.name()});
    try tty.color(.reset);
    try tty.print(" {s}", .{host.emoji()});

    try context.print(&tty);

    const path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(path);

    try tty.color(.dim);
    try tty.write(" ");
    if (path.len < tty.remaining()) {
        try tty.print("{s}\n", .{path});
    } else {
        try tty.print("{s}…\n", .{path[0 .. tty.remaining() - 1]});
    }
    try tty.color(.reset);

    try tty.color(.blue);
    try tty.print("→ ", .{});

    try tty.color(.reset);
}
