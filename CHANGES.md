# p99.Zig CHANGES <!-- omit in toc -->


## 0.0.3 - 26th July 2026

Added `binary-scaling` optimisation

* Implemented optional $2^{32}$ fixed-point binary scaling float-avoidance optimizations from `p99.Rust` as a comptime build option (`-Dbinary-scaling`);
* Added `binary-scaling` option to `build.zig` and passed it to the root module as `build_options`;
* Updated integer-based percentile methods (`valueAtP90`, `valueAtP95`, `valueAtP99`, etc.) to use pre-encoded $2^{32}$ fixed-point multipliers when `binary_scaling` is enabled;
* Bumped package version to `0.0.3`;


## 0.0.2 - 26th July 2026

GitHub Actions CI

* Added GitHub Actions CI workflow (`.github/workflows/ci.yml`) supporting Linux, macOS, and Windows;
* Configured CI to run formatting checks (`zig fmt --check .`);
* Configured CI to run unit tests, compile and run the example, and run the benchmark suite;
* Bumped package version to `0.0.2`;


## 0.0.1 - 26th July 2026

Core logic

* Implemented core `Histogram` struct with 64-bucket logarithmic power-of-two spacing;
* Implemented branchless bucket indexing via CPU `@clz` (count leading zeros) instruction;
* Implemented linear interpolation for percentile approximation;
* Added comprehensive unit tests covering default initialization, bucket calculations, event pushing, overflow handling, and percentile accuracy;
* Added benchmark suite using the modern Zig 0.16.0 `std.Io.Clock` API;
* Added example program demonstrating basic usage;
* Refactored all examples, benchmarks, and client code to use standard `stdout` buffered writing;
* Updated `README.md` with standard installation instructions and minimal example;


## 0.0.0 - 26th July 2026

First public release (boilerplate skeleton)


<!-- ########################### end of file ########################### -->
