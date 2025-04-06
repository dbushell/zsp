const std = @import("std");
const config = @import("config");
const minizign = @import("minizign");
const TTY = @import("./TTY.zig");
const Allocator = std.mem.Allocator;
const Version = std.SemanticVersion;
const fs = std.fs;

pub const UpdateError = error{
    ApiError,
    DownloadError,
    FileError,
    ParseError,
    SigError,
    InstallError,
};

pub const build_name: []const u8 = config.name;
pub const build_triple: []const u8 = config.triple;
pub const build_version: Version = config.version;

// Should I be using path builder? (Windows is not supported)
const tmp_path = "/tmp/zsp";
const tar_prefix = build_name ++ "-" ++ build_triple;
const tar_name = tar_prefix ++ ".tar.gz";
const tar_path = tmp_path ++ "/" ++ tar_name;
const sig_name = tar_name ++ ".minisig";
const sig_path = tmp_path ++ "/" ++ sig_name;

/// Partial JSON schema for GitHub "List Releases" API
/// https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases
pub const Release = struct {
    tag_name: []const u8,
    assets: []struct {
        name: []const u8,
        size: usize,
        browser_download_url: []const u8,
    },
    // Not part of JSON reponse, is this allowed?
    version: ?Version = null,
};

pub const UpdateOptions = struct {
    /// Reinstall current version
    force: bool,
};

pub fn download(allocator: Allocator, options: UpdateOptions) UpdateError!Version {
    // Rely on CURL because HTTP library is large
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .max_output_bytes = 1024 * 1024,
        .argv = &.{
            "curl",
            "-L",
            "-H",
            "Accept: application/vnd.github+json",
            "-H",
            "X-GitHub-Api-Version: 2022-11-28",
            "https://api.github.com/repos/dbushell/zsp/releases",
        },
    }) catch return error.ApiError;
    defer {
        allocator.free(result.stderr);
        allocator.free(result.stdout);
    }
    if (result.term != .Exited) return error.ApiError;

    // Parse JSON body
    var releases = std.json.parseFromSlice(
        []Release,
        allocator,
        result.stdout,
        .{ .ignore_unknown_fields = true },
    ) catch return error.ParseError;
    defer releases.deinit();

    // Find latest release by semver
    var latest: ?*Release = null;
    for (releases.value) |*release| {
        if (release.tag_name[0] != 'v') continue;
        release.version = Version.parse(release.tag_name[1..]) catch continue;
        if (!options.force) {
            if (release.version.?.order(build_version) != .gt) continue;
        }
        if (latest) |l| {
            if (release.version.?.order(l.version.?) == .gt) latest = release;
        } else latest = release;
    }
    if (latest == null) return build_version;

    var dir = ensureDir(tmp_path) catch return error.FileError;
    defer {
        // Cleanup temporary files
        var iter = dir.iterate();
        while (iter.next()) |next| {
            if (next) |entry| {
                dir.deleteFile(entry.name) catch continue;
            } else break;
        } else |_| {}
        dir.close();
        fs.deleteDirAbsolute(tmp_path) catch {};
    }
    for (latest.?.assets) |asset| {
        downloadFile(allocator, asset.browser_download_url) catch return error.DownloadError;
    }
    // Check archive was downloaded
    fs.accessAbsolute(tar_path, .{ .mode = .read_only }) catch return error.FileError;
    validateSignature(allocator) catch return error.SigError;
    installBinary(allocator, dir) catch return error.InstallError;
    return latest.?.version.?;
}

/// Open directory (create if it does not exist)
pub fn ensureDir(path: []const u8) !fs.Dir {
    const dir_options: fs.Dir.OpenDirOptions = .{ .iterate = true };
    return fs.openDirAbsolute(path, dir_options) catch {
        try fs.makeDirAbsolute(path);
        return try fs.openDirAbsolute(path, dir_options);
    };
}

/// Save remote file to temporary directory
fn downloadFile(allocator: Allocator, url: []const u8) !void {
    const is_native = std.mem.containsAtLeast(u8, url, 1, tar_prefix);
    if (!is_native) return;
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-O", "-L", url },
        .cwd = tmp_path,
    });
    allocator.free(result.stderr);
    allocator.free(result.stdout);
    if (result.term != .Exited) return error.DownloadError;
}

fn validateSignature(allocator: Allocator) !void {
    try fs.accessAbsolute(sig_path, .{ .mode = .read_only });
    const file = try fs.openFileAbsolute(tar_path, .{ .mode = .read_only });
    defer file.close();
    const pubkey = try minizign.PublicKey.decodeFromBase64(config.minisign_public_key);
    var signature = try minizign.Signature.fromFile(allocator, sig_path);
    defer signature.deinit();
    try pubkey.verifyFile(allocator, file, signature, false);
}

fn installBinary(allocator: Allocator, dir: fs.Dir) !void {
    // Extract archive
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "tar", "-xf", tar_path },
        .cwd_dir = dir,
    });
    allocator.free(result.stderr);
    allocator.free(result.stdout);
    if (result.term != .Exited) return error.InstallError;
    // Replace existing binary
    const exe_path = try fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    try fs.deleteFileAbsolute(exe_path);
    try fs.copyFileAbsolute(tmp_path ++ "/zsp", exe_path, .{});
}
