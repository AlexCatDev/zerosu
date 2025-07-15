const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    std.debug.print("!!Compiling for OS: {s} ARCH: {s}\n", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) });

    const exe_example = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (optimize != .Debug) {
        std.debug.print("Not A Debug Build, Stripping binary", .{});
        exe_example.strip = true;
        exe_example.error_tracing = false;
        exe_example.fuzz = false;
        exe_example.omit_frame_pointer = true;
        exe_example.valgrind = false;
        exe_example.unwind_tables = null;
        exe_example.single_threaded = true;
        exe_example.sanitize_thread = false;
    }

    //exe_example.addRPathSpecial("$ORIGIN");
    const exe = b.addExecutable(.{
        .name = "zerosu",
        .root_module = exe_example,
    });

    if (target.result.cpu.arch.isArm()) {
        //my pi zero2
        exe.addLibraryPath(.{ .cwd_relative = "/home/alex/Downloads/piroot/usr/lib/arm-linux-gnueabihf/" });
        exe.addIncludePath(.{ .cwd_relative = "/home/alex/Downloads/piroot/usr/include/arm-linux-gnueabihf/" });
        exe.addIncludePath(.{ .cwd_relative = "/home/alex/Downloads/piroot/usr/include/" });
    }

    exe.addIncludePath(.{ .cwd_relative = "c" });
    exe.addCSourceFile(.{ .file = .{
        .cwd_relative = "c/stb_image_impl.c",
    } });

    //if (target.result.os)
    const targetCpu = target.result.cpu.arch;
    const targetOs = target.result.os.tag;

    const libsLibPath = switch (targetOs) {
        .linux => "libs/linux",
        else => @panic("Unsupported arch"),
    };
    exe.addLibraryPath(.{ .cwd_relative = libsLibPath });

    //Link Bass

    //Will append lib before this path even tho i dont want it
    const bassLibPath = switch (targetCpu) {
        .x86_64 => "_x86_64/libbass",
        .arm => "_armhf/libbass",
        .aarch64 => "_aarch64/libbass",
        else => @panic("Unsupported arch"),
    };
    exe.linkSystemLibrary(bassLibPath);

    //const finalLibPath = try concatThreeStrings(b.allocator, libsLibPath, "lib", bassLibPath);
    const libOutputPath = std.fmt.allocPrint(b.allocator, "{s}/lib{s}.so", .{ libsLibPath, bassLibPath }) catch return;
    defer b.allocator.free(libOutputPath);
    //Copy basslib file to bin
    b.installBinFile(libOutputPath, libOutputPath);

    //LINK_BASS(b, exe);

    const zm = b.dependency("zm", .{});
    exe.root_module.addImport("zm", zm.module("zm"));

    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("GLESv2");

    const maps_dir = "maps";
    const skins_dir = "skins";
    addDirToOutput(b, maps_dir);
    addDirToOutput(b, skins_dir);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn LINK_BASS(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const target = b.standardTargetOptions(.{});

    const targetCpu = target.result.cpu.arch;
    const targetOs = target.result.os.tag;

    const libsLibPath = switch (targetOs) {
        .linux => "libs/linux",
        else => @panic("Unsupported arch"),
    };
    exe.addLibraryPath(.{ .cwd_relative = libsLibPath });

    //Will append lib before this path even tho i dont want it
    const bassLibPath = switch (targetCpu) {
        .x86_64 => "_x86_64/libbass",
        .arm => "_armhf/libbass",
        .aarch64 => "_aarch64/libbass",
        else => @panic("Unsupported arch"),
    };
    exe.linkSystemLibrary(bassLibPath);

    //const finalLibPath = try concatThreeStrings(b.allocator, libsLibPath, "lib", bassLibPath);
    const finalLibPath = std.fmt.allocPrint(b.allocator, "{s}/lib{s}.so", .{ libsLibPath, bassLibPath }) catch return;
    defer b.allocator.free(finalLibPath);
    b.installBinFile(finalLibPath, finalLibPath);
}

fn addDirToOutput(b: *std.Build, dir_name: []const u8) void {
    b.installDirectory(.{
        .source_dir = .{ .cwd_relative = dir_name },
        .install_dir = .bin,
        .install_subdir = dir_name,
    });
}
