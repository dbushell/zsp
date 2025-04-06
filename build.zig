const std = @import("std");
// const zon: struct { version: []const u8 } = @import("./build.zig.zon");

const name = "zsp";
const version = std.SemanticVersion.parse("0.7.0") catch unreachable;

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const tarball = b.option(
        bool,
        "tarball",
        "Generate tarball with signature",
    ) orelse false;

    for (targets) |t| {
        const triple = try t.zigTriple(b.allocator);
        const target = b.resolveTargetQuery(t);

        const minizign = b.dependency("minizign", .{
            .target = target,
            .optimize = optimize,
        });

        const mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        const options = b.addOptions();
        options.addOption([]const u8, "name", name);
        options.addOption([]const u8, "triple", triple);
        options.addOption(std.SemanticVersion, "version", version);
        options.addOption([]const u8, "minisign_public_key", "RWRdnhTwGE7SUzRJwb+f48phQN3hyxCfOXXpOBBFq9L1BwFU51JlXly2");
        mod.addOptions("config", options);
        mod.addImport("minizign", minizign.module("minizign"));

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = mod,
        });
        const exe_dir = exe.getEmittedBinDirectory();

        const out = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{ .custom = triple },
            },
        });
        b.getInstallStep().dependOn(&out.step);

        if (tarball) {
            // Archive executable
            const tar_name = try std.mem.concat(b.allocator, u8, &.{ name, "-", triple, ".tar.gz" });
            const tar = b.addSystemCommand(&.{"tar"});
            tar.setCwd(exe_dir);
            tar.addArgs(&.{"-czf"});
            tar.addArg(tar_name);
            tar.addArg(exe.out_filename);
            tar.step.dependOn(&out.step);

            // Sign archive file
            const sign_name = try std.mem.concat(b.allocator, u8, &.{ tar_name, ".minisig" });
            const sign = b.addSystemCommand(&.{"minisign"});
            sign.addPrefixedFileArg("-Sm", exe_dir.path(b, tar_name));
            sign.addPrefixedFileArg("-x", exe_dir.path(b, sign_name));
            sign.addPrefixedFileArg("-s", b.path("minisign.key"));
            sign.step.dependOn(&tar.step);

            const install_tar = b.addInstallFile(
                exe_dir.path(b, tar_name),
                b.pathJoin(&.{ triple, tar_name }),
            );
            install_tar.step.dependOn(&tar.step);
            b.getInstallStep().dependOn(&install_tar.step);

            const install_sign = b.addInstallFile(
                exe_dir.path(b, sign_name),
                b.pathJoin(&.{ triple, sign_name }),
            );
            install_sign.step.dependOn(&sign.step);
            b.getInstallStep().dependOn(&install_sign.step);
        }

        // Use `zig build run` for debug
        if (optimize == .Debug and t.os_tag == .macos) {
            const run_cmd = b.addRunArtifact(exe);
            run_cmd.addArgs(b.args orelse &.{"prompt"});
            run_cmd.step.dependOn(b.getInstallStep());
            const run_step = b.step("run", "Run");
            run_step.dependOn(&run_cmd.step);
        }
    }
}
