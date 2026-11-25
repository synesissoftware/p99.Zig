const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build option for binary scaling (mirroring Rust's feature flag)
    const binary_scaling = b.option(
        bool,
        "binary-scaling",
        "Enable 2^32 fixed-point binary scaling for integer-based percentile queries (default: false)",
    ) orelse false;

    // Create a module for other packages to import
    const p99_module = b.addModule("p99", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options to the module
    const options = b.addOptions();
    options.addOption(bool, "binary_scaling", binary_scaling);
    p99_module.addOptions("build_options", options);

    // Static library using the module
    const lib = b.addLibrary(.{
        .name = "p99",
        .linkage = .static,
        .root_module = p99_module,
    });
    b.installArtifact(lib);

    // Unit tests using the module
    const lib_unit_tests = b.addTest(.{
        .root_module = p99_module,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Example: build_histogram
    const example = b.addExecutable(.{
        .name = "build_histogram",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/build_histogram.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("p99", p99_module);
    b.installArtifact(example);

    const run_example = b.addRunArtifact(example);
    // Zig 0.17 forwards `zig build run -- …` through `addPassthruArgs`.
    // Zig 0.16 still exposes those arguments as `b.args`.
    if (comptime @hasDecl(std.Build.Step.Run, "addPassthruArgs")) {
        run_example.addPassthruArgs();
    } else if (b.args) |args| {
        run_example.addArgs(args);
    }

    const run_example_step = b.step("run-example", "Run the examples");
    run_example_step.dependOn(&run_example.step);

    // Example: show_version
    const show_version = b.addExecutable(.{
        .name = "show_version",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/show_version.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    show_version.root_module.addImport("p99", p99_module);
    b.installArtifact(show_version);

    const run_show_version = b.addRunArtifact(show_version);
    // Zig 0.17 forwards `zig build run -- …` through `addPassthruArgs`.
    // Zig 0.16 still exposes those arguments as `b.args`.
    if (comptime @hasDecl(std.Build.Step.Run, "addPassthruArgs")) {
        run_show_version.addPassthruArgs();
    } else if (b.args) |args| {
        run_show_version.addArgs(args);
    }

    const run_show_version_step = b.step("run-show-version", "Run the show_version example");
    run_show_version_step.dependOn(&run_show_version.step);
    run_example_step.dependOn(&run_show_version.step);

    // Benchmark: benchmark_histogram
    const bench = b.addExecutable(.{
        .name = "benchmark_histogram",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benches/benchmark_histogram.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench.root_module.addImport("p99", p99_module);
    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    // Zig 0.17 forwards `zig build run -- …` through `addPassthruArgs`.
    // Zig 0.16 still exposes those arguments as `b.args`.
    if (comptime @hasDecl(std.Build.Step.Run, "addPassthruArgs")) {
        run_bench.addPassthruArgs();
    } else if (b.args) |args| {
        run_bench.addArgs(args);
    }

    const run_bench_step = b.step("bench", "Run the benchmark_histogram suite");
    run_bench_step.dependOn(&run_bench.step);
}
