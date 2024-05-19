const std = @import("std");
const rl = @import("raylib");

pub fn build(b: *std.Build) void {
    // == build options ==
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse optimize;
    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;

    // == dependencies ==
    const raylib = try rl.addRaylib(b, target, raylib_optimize, .{});
    // const raygui_dep = b.dependency("raygui", .{});
    // rl.addRaygui(b, raylib, raygui_dep);
    // const raylib_dep = b.dependency("raylib", .{
    //     .target = target,
    //     .optimize = raylib_optimize,
    // });
    // const raylib = raylib_dep.artifact("raylib");

    // == build executable ==
    const exe = b.addExecutable(.{
        .name = "conway",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib);
    exe.root_module.strip = strip;
    b.installArtifact(exe);

    // == builds tests ==
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // == commands ==
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // === define steps ===
    // zig build run
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    // zig build test
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
