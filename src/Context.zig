const std = @import("std");
const TTY = @import("./TTY.zig");
const Prop = @import("./prop.zig").Prop;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const Dir = std.fs.Dir;
const eql = std.mem.eql;
const extension = std.fs.path.extension;

/// Limit number of parent directories to scan (inclusive of current directory)
const max_scan_depth = 5;

const Self = @This();

allocator: Allocator,
cwd: Dir,
props: AutoHashMap(Prop, void),
// Current git repo directory name
repo: ?[]const u8 = null,

pub fn init(allocator: Allocator, cwd: Dir) Self {
    return Self{
        .allocator = allocator,
        .cwd = cwd,
        .props = AutoHashMap(Prop, void).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    if (self.repo) |p| self.allocator.free(p);
    self.props.deinit();
}

pub fn is(self: Self, prop: Prop) bool {
    return self.props.contains(prop);
}

/// Write formatted prompt line
pub fn print(self: Self, tty: *TTY) !void {
    if (self.repo) |p| {
        tty.ansi(&.{.reset});
        tty.print(" | ", .{});
        tty.ansi(&.{ .cyan, .bold });
        tty.print("{s}", .{p});
    }
    inline for (std.meta.fields(Prop)) |field| {
        const prop: Prop = @enumFromInt(field.value);
        if (self.props.contains(prop) and prop != .git) {
            tty.ansi(&.{.reset});
            tty.write(" | ");
            tty.ansi(&.{.yellow});
            tty.write(prop.symbol());
            const version = prop.version(self.allocator);
            if (version) |string| {
                defer self.allocator.free(string);
                tty.write(" ");
                tty.write(prop.versionFormat(string));
            }
        }
    }
    if (self.is(.git)) {
        if (self.gitBranch()) |branch| {
            const dirty = self.gitDirty();
            defer self.allocator.free(branch);
            tty.ansi(&.{.reset});
            tty.write(" on ");
            if (dirty) {
                tty.ansi(&.{ .red, .bold });
            } else {
                tty.ansi(&.{ .magenta, .bold });
            }
            tty.print("{s} {s}{s}", .{
                Prop.git.symbol(),
                std.mem.trimRight(u8, branch, " \n"),
                if (dirty) "*" else "",
            });
        }
    }
    tty.ansi(&.{.reset});
}

/// Scan parent directories to populate context
pub fn scan(self: *Self) !void {
    var dir = try self.cwd.openDir(".", .{ .iterate = true });
    defer dir.close();
    var depth: usize = 0;
    while (true) : (depth += 1) {
        if (depth == max_scan_depth) break;
        const path = try dir.realpathAlloc(self.allocator, ".");
        defer self.allocator.free(path);
        self.scanDirectory(&dir, std.fs.path.basename(path));
        const parent = try dir.openDir("../", .{ .iterate = true });
        dir.close();
        dir = parent;
        // Exit once root is reached
        if (eql(u8, path, "/")) break;
    }
    // Remove Node.js false positive
    if (self.is(.node)) {
        if (self.is(.bun) or self.is(.deno)) {
            _ = self.props.remove(.node);
        }
    }
}

/// Check all entries inside the open directory
fn scanDirectory(self: *Self, dir: *Dir, dir_name: []const u8) void {
    var iter = dir.iterate();
    while (iter.next()) |next| {
        if (next) |entry| self.scanEntry(entry, dir_name) else break;
    } else |_| return;
}

/// Check an individual directory entry
fn scanEntry(self: *Self, entry: Dir.Entry, dir_name: []const u8) void {
    const result: ?Prop = switch (entry.kind) {
        .directory => result: {
            if (eql(u8, entry.name, ".git")) {
                if (self.repo) |p| self.allocator.free(p);
                self.repo = self.allocator.dupe(u8, dir_name) catch null;
                break :result .git;
            } else if (eql(u8, entry.name, "node_modules")) {
                break :result .node;
            } else if (eql(u8, entry.name, "zig-out")) {
                break :result .zig;
            }
            break :result null;
        },
        .file, .sym_link => result: {
            const ext = extension(entry.name);
            if (eql(u8, entry.name, "bun.lock")) {
                break :result .bun;
            } else if (eql(u8, entry.name, "bun.lockb")) {
                break :result .bun;
            } else if (eql(u8, entry.name, "bunfig.toml")) {
                break :result .bun;
            } else if (eql(u8, entry.name, "Cargo.lock")) {
                break :result .rust;
            } else if (eql(u8, entry.name, "Cargo.toml")) {
                break :result .rust;
            } else if (eql(u8, entry.name, "deno.json")) {
                break :result .deno;
            } else if (eql(u8, entry.name, "deno.jsonc")) {
                break :result .deno;
            } else if (eql(u8, entry.name, "deno.lock")) {
                break :result .deno;
            } else if (eql(u8, entry.name, "docker-compose.yml")) {
                break :result .docker;
            } else if (eql(u8, entry.name, "package.json")) {
                break :result .node;
            } else if (eql(u8, ext, ".php")) {
                break :result .php;
            } else if (eql(u8, ext, ".rs")) {
                break :result .rust;
            } else if (eql(u8, ext, ".zig")) {
                break :result .zig;
            }
            break :result null;
        },
        else => null,
    };
    if (result) |prop| {
        self.props.put(prop, {}) catch unreachable;
    }
}

fn gitBranch(self: Self) ?[]const u8 {
    if (!self.is(.git)) return null;
    const result = std.process.Child.run(.{
        .allocator = self.allocator,
        .argv = &.{ "git", "branch", "--show-current" },
    }) catch return null;
    if (result.term == .Exited) {
        self.allocator.free(result.stderr);
        return result.stdout;
    }
    self.allocator.free(result.stderr);
    self.allocator.free(result.stdout);
    return null;
}

fn gitDirty(self: Self) bool {
    if (!self.is(.git)) return false;
    const result = std.process.Child.run(.{
        .allocator = self.allocator,
        .argv = &.{ "git", "diff", "--no-ext-diff", "--quiet", "--exit-code" },
    }) catch return false;
    self.allocator.free(result.stderr);
    self.allocator.free(result.stdout);
    return switch (result.term) {
        .Exited => |code| (code == 1),
        else => false,
    };
}
