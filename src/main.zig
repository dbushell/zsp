const std = @import("std");
const Args = @import("./Args.zig");
const Context = @import("./Context.zig");
const Host = @import("./Host.zig");
const TTY = @import("./TTY.zig");
const Prop = @import("./prop.zig").Prop;
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
    try context.scan();

    var host = Host{};

    tty.write("\n");
    tty.ansi(&.{.dim});
    tty.print("{s}", .{host.user()});
    tty.ansi(&.{ .reset, .green });
    tty.print("@{s}", .{try host.name()});
    tty.ansi(&.{.reset});
    tty.print(" {s}", .{host.emoji()});

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
    tty.ansi(&.{.dim});
    tty.write(" ");
    if (cwd_home) tty.write("~");
    if (cwd.len < tty.remaining()) {
        tty.print("{s}", .{cwd});
    } else if (tty.remaining() > 10) {
        tty.print("{s}…", .{cwd[0 .. tty.remaining() - 1]});
    }
    tty.ansi(&.{.reset});

    // New line for input command
    tty.ansi(&.{ .cyan, .bold });
    tty.write("\n");
    if (host.ssh()) tty.write("SSH ");
    tty.print("→ ", .{});
    tty.ansi(&.{.reset});
}
