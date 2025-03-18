const std = @import("std");
const Allocator = std.mem.Allocator;
const isDigit = std.ascii.isDigit;

pub const Prop = enum {
    bun,
    deno,
    docker,
    git,
    go,
    node,
    php,
    python,
    rust,
    zig,

    /// Nerd font unicode characters
    pub fn symbol(prop: Prop) []const u8 {
        return switch (prop) {
            .bun => "🍞",
            .deno => "🦕",
            .docker => "🐳",
            .git => "",
            .go => "🐹",
            .node => "⬡",
            .php => "🐘",
            .python => "🐍",
            .rust => "🦀",
            .zig => "⚡",
        };
    }

    /// Spawn child process to get the version string.
    /// If successful, caller owns result.
    pub fn version(prop: Prop, allocator: Allocator) ?[]const u8 {
        if (prop.versionArgv()) |argv| {
            const result = std.process.Child.run(.{
                .allocator = allocator,
                .argv = argv,
            }) catch return null;
            if (result.term == .Exited) {
                allocator.free(result.stderr);
                return result.stdout;
            }
            allocator.free(result.stderr);
            allocator.free(result.stdout);
        }
        return null;
    }

    /// Get the version command arguments
    pub fn versionArgv(prop: Prop) ?[]const []const u8 {
        return switch (prop) {
            .bun => &.{ "bun", "-v" },
            .deno => &.{ "deno", "-v" },
            .docker => &.{ "docker", "-v" },
            .go => &.{ "go", "version" },
            .node => &.{ "node", "-v" },
            .php => &.{ "php", "--version" },
            .python => &.{ "python", "--version" },
            .rust => &.{ "rustc", "--version" },
            .zig => &.{ "zig", "version" },
            else => null,
        };
    }

    /// Returns a trimmed version slice, e.g. "1.0.0"
    pub fn versionFormat(prop: Prop, string: []const u8) []const u8 {
        _ = prop;
        var start: usize = 0;
        var end: usize = 0;
        for (0..string.len) |i| if (isDigit(string[i])) {
            start = i;
            break;
        };
        for (start..string.len) |i| if (string[i] != '.' and !isDigit(string[i])) {
            end = i;
            break;
        };
        return if (start < end) string[start..end] else "";
    }
};
