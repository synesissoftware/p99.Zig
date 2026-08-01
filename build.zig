const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module for other packages to import
    const p99_module = b.addModule("p99", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

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
    if (b.args) |args| {
        run_example.addArgs(args);
    }

    const run_example_step = b.step("run-example", "Run the build_histogram example");
    run_example_step.dependOn(&run_example.step);

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
    if (b.args) |args| {
        run_bench.addArgs(args);
    }

    const run_bench_step = b.step("bench", "Run the benchmark_histogram suite");
    run_bench_step.dependOn(&run_bench.step);
}
