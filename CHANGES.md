# p99.Zig CHANGES <!-- omit in toc -->


## 0.0.1 - 26th July 2026

Core logic

* Implemented core `Histogram` struct with 64-bucket logarithmic power-of-two spacing.
* Implemented branchless bucket indexing via CPU `@clz` (count leading zeros) instruction.
* Implemented linear interpolation for percentile approximation.
* Added comprehensive unit tests covering default initialization, bucket calculations, event pushing, overflow handling, and percentile accuracy.
* Added benchmark suite using the modern Zig 0.16.0 `std.Io.Clock` API.
* Added example program demonstrating basic usage.
* Refactored all examples, benchmarks, and client code to use standard `stdout` buffered writing.
* Updated `README.md` with standard installation instructions and minimal example.


## 0.0.0 - 26th July 2026

First public release (boilerplate skeleton)


<!-- ########################### end of file ########################### -->
