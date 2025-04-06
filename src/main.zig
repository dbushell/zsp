const std = @import("std");
const builtin = @import("builtin");
const update = @import("./update.zig");
const Args = @import("./Args.zig");
const Context = @import("./Context.zig");
const Host = @import("./Host.zig");
const TTY = @import("./TTY.zig");
const Prop = @import("./prop.zig").Prop;
const Allocator = std.mem.Allocator;

const init_zsh = @embedFile("./shell/zsh.sh");

const default_columns: usize = 80;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator, const is_debug = alloc: {
        break :alloc switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var args: Args = try .init(allocator);
    defer args.deinit();

    const columns: usize = if (args.items.get("columns")) |entry| value: {
        break :value entry.int;
    } else default_columns;

    var tty: TTY = .init(columns);

    if (args.items.contains("-v")) {
        tty.print("{}\n", .{update.build_version});
        return;
    }

    if (args.items.contains("version")) {
        tty.print("zsp {} ({s})\n", .{
            update.build_version,
            update.build_triple,
        });
        return;
    }

    if (args.items.contains("zsh")) {
        tty.write(init_zsh);
        return;
    }

    if (args.items.contains("update")) {
        return updateCommand(allocator, &args, &tty);
    }

    if (args.items.contains("prompt")) {
        return promptCommand(allocator, &args, &tty);
    }
}

fn updateCommand(allocator: Allocator, args: *Args, tty: *TTY) !void {
    tty.print(
        "Current version: {}\n",
        .{update.build_version},
    );
    const options = update.UpdateOptions{
        .force = args.items.contains("force"),
    };
    if (update.download(allocator, options)) |version| {
        switch (version.order(update.build_version)) {
            .gt => tty.print("New version: {}\n", .{version}),
            .lt => tty.print("Old version: {}\n", .{version}),
            .eq => tty.write("Up to date\n"),
        }
    } else |err| {
        const reason = switch (err) {
            error.ApiError => "API not responding",
            error.DownloadError => "error downloading files",
            error.FileError => "error writing temporary files",
            error.ParseError => "could not parse API response",
            error.SigError => "invalid tarball signature",
            error.InstallError => "error installing binary (sudo required?)",
        };
        tty.print("Update failed: {s}\n", .{reason});
    }
}

fn promptCommand(allocator: Allocator, args: *Args, tty: *TTY) !void {
    var context: Context = .init(allocator, std.fs.cwd());
    defer context.deinit();
    try context.scan();
    try context.git.update();

    var host: Host = .{};

    // Print "user@host [emoji]"
    tty.write("\n");
    tty.ansi(&.{.dim});
    tty.print("{s}", .{host.user()});
    tty.ansi(&.{ .reset, .green });
    tty.print("@{s}", .{try host.name()});
    tty.ansi(&.{.reset});
    tty.print(" {s}", .{host.emoji()});

    // Print: " | 404ms"
    // Last command execution time from ZSH script
    if (args.items.get("duration")) |duration| {
        if (duration == .int and duration.int >= 100) {
            tty.ansi(&.{.reset});
            const time = std.fmt.fmtDuration(@intCast(std.time.ns_per_ms * duration.int));
            tty.print(" | {d}", .{time});
        }
    }

    // Print: " | [repo]"
    // Directory name of parent Git repository
    if (context.repo) |repo| {
        tty.ansi(&.{.reset});
        tty.print(" | ", .{});
        tty.ansi(&.{ .cyan, .bold });
        tty.print("{s}", .{repo});
    }

    // Print: " | [emoji] 1.2.3"
    // Version of each programming language detected
    inline for (std.meta.fields(Prop)) |field| {
        const prop: Prop = @enumFromInt(field.value);
        if (context.is(prop) and prop != .git) {
            tty.ansi(&.{.reset});
            tty.write(" | ");
            tty.ansi(&.{.yellow});
            tty.write(prop.symbol());
            const version = prop.version(context.allocator);
            if (version) |string| {
                defer context.allocator.free(string);
                tty.write(" ");
                tty.write(prop.versionFormat(string));
            }
        }
    }

    // Print: " on ↑ main*"
    // Git branch and repository status
    if (context.is(.git)) {
        tty.ansi(&.{.reset});
        tty.write(" on ");
        if (context.git.state == .dirty) {
            tty.ansi(&.{ .red, .bold });
        } else {
            tty.ansi(&.{ .magenta, .bold });
        }
        tty.print("{s}{s} {s}{s}", .{
            Prop.git.symbol(),
            switch (context.git.stature) {
                .ahead => "↑",
                .behind => "↓",
                .diverged => "‼",
                else => "",
            },
            context.git.branch,
            if (context.git.state == .dirty) "*" else "",
        });
    }

    // Use remaining space for current path
    var cwd = context.cwd_path orelse "/";
    var cwd_home = false;
    if (host.home()) |home| {
        if (std.mem.startsWith(u8, cwd, home)) {
            cwd = cwd[home.len..];
            cwd_home = true;
        }
    }
    tty.ansi(&.{ .reset, .dim });
    tty.write(" ");
    if (context.cwd_readonly) tty.write("🔒");
    if (cwd_home) tty.write("~");
    if (cwd.len < tty.remaining()) {
        tty.print("{s}", .{cwd});
    } else if (tty.remaining() > 10) {
        tty.print("{s}…", .{cwd[0 .. tty.remaining() - 1]});
    }

    // New line for input command
    tty.ansi(&.{ .reset, .cyan, .bold });
    tty.write("\n");
    if (host.ssh()) tty.write("SSH ");
    tty.print("→ ", .{});

    tty.ansi(&.{.reset});
}
