const std = @import("std");
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const containsAtLeast = std.mem.containsAtLeast;
const startsWith = std.mem.startsWith;

const Self = @This();

pub const State = enum {
    clean,
    dirty,
    unknown,
};

pub const Stature = enum {
    ahead,
    behind,
    uptodate,
    diverged,
    unknown,
};

allocator: Allocator,
state: State = .unknown,
stature: Stature = .unknown,
branch: []const u8 = "",

pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    if (self.branch.len > 0) self.allocator.free(self.branch);
    self.* = undefined;
}

pub fn reset(self: *Self) void {
    if (self.branch.len > 0) {
        self.allocator.free(self.branch);
        self.branch = "";
    }
    self.state = .unknown;
    self.stature = .unknown;
}

pub fn update(self: *Self) !void {
    self.reset();
    const result = std.process.Child.run(.{
        .allocator = self.allocator,
        .argv = &.{ "git", "status" },
    }) catch return;
    defer {
        self.allocator.free(result.stderr);
        self.allocator.free(result.stdout);
    }
    if (result.term != .Exited) return;
    // Iterate stdout line by line
    var lines = std.mem.tokenizeScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (self.state != .unknown and self.stature != .unknown) {
            break;
        }
        // Read branch name
        if (self.branch.len == 0 and startsWith(u8, line, "On branch ")) {
            const branch = line[10..]; // Skip "On branch "
            if (self.allocator.alloc(u8, branch.len)) |string| {
                self.branch = string;
                @memcpy(@constCast(self.branch), branch);
            } else |_| self.branch = "";
            continue;
        }
        // Read branch stature
        if (self.stature == .unknown and startsWith(u8, line, "Your branch ")) {
            const slice = line[15..]; // Skip "Your branch is "
            if (eql(u8, slice[0..5], "ahead")) {
                self.stature = .ahead;
            } else if (eql(u8, slice[0..6], "behind")) {
                self.stature = .behind;
            } else if (eql(u8, slice[0..10], "up to date")) {
                self.stature = .uptodate;
            } else if (containsAtLeast(u8, slice, 1, "diverged")) {
                self.stature = .diverged;
            }
            continue;
        }
        // Read change state
        if (self.state == .unknown) {
            if (startsWith(u8, line, "nothing to commit")) {
                self.state = .clean;
            } else if (startsWith(u8, line, "Changes")) {
                self.state = .dirty;
            }
        }
    }
}
