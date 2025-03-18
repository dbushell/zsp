const std = @import("std");
const Git = @import("./Git.zig");
const TTY = @import("./TTY.zig");
const Prop = @import("./prop.zig").Prop;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMapUnmanaged;
const Dir = std.fs.Dir;
const eql = std.mem.eql;
const extension = std.fs.path.extension;

/// Limit number of parent directories to scan (inclusive of current directory)
const max_scan_depth = 5;

const Self = @This();

allocator: Allocator,
git: Git,
props: AutoHashMap(Prop, void),
// Current git repo directory name
repo: ?[]const u8 = null,
/// Current directory
cwd: Dir,
/// Current directory path
cwd_path: ?[]const u8 = null,
/// Current directory is readonly
cwd_readonly: bool = false,

pub fn init(allocator: Allocator, cwd: Dir) Self {
    return Self{
        .allocator = allocator,
        .cwd = cwd,
        .git = .init(allocator),
        .props = .empty,
    };
}

pub fn deinit(self: *Self) void {
    if (self.repo) |p| self.allocator.free(p);
    if (self.cwd_path) |p| self.allocator.free(p);
    self.props.deinit(self.allocator);
    self.git.deinit();
    self.* = undefined;
}

pub fn is(self: Self, prop: Prop) bool {
    return self.props.contains(prop);
}

/// Scan parent directories to populate context
pub fn scan(self: *Self) !void {
    var dir = try self.cwd.openDir(".", .{ .iterate = true });
    defer dir.close();
    self.cwd_path = try dir.realpathAlloc(self.allocator, ".");
    if (dir.access(".", .{ .mode = .read_write })) {
        self.cwd_readonly = false;
    } else |_| {
        self.cwd_readonly = true;
    }
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
            } else if (eql(u8, ext, ".go")) {
                break :result .go;
            } else if (eql(u8, ext, ".php")) {
                break :result .php;
            } else if (eql(u8, ext, ".py")) {
                break :result .python;
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
        self.props.put(self.allocator, prop, {}) catch unreachable;
    }
}
