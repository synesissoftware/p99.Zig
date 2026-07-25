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
    if (b.args) |args| {
        run_example.addArgs(args);
    }

    const run_example_step = b.step("run-example", "Run the build_histogram example");
    run_example_step.dependOn(&run_example.step);
}
