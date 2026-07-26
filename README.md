# p99.Zig <!-- omit in toc -->

![Language](https://img.shields.io/badge/Zig-F7A41D?style=flat&logo=zig&logoColor=white)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![GitHub release](https://img.shields.io/github/v/release/synesissoftware/p99.Zig.svg)](https://github.com/synesissoftware/p99.Zig/releases/latest)
[![Last Commit](https://img.shields.io/github/last-commit/synesissoftware/p99.Zig)](https://github.com/synesissoftware/p99.Zig/commits/master)
[![CI](https://github.com/synesissoftware/p99.Zig/actions/workflows/ci.yml/badge.svg)](https://github.com/synesissoftware/p99.Zig/actions/workflows/ci.yml)

Very low-cost measuring of performance percentiles, for Zig


## Table of Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [How It Works](#how-it-works)
- [Installation](#installation)
- [Minimal Example](#minimal-example)
- [Project Information](#project-information)
  - [Where to get help](#where-to-get-help)
  - [Contribution guidelines](#contribution-guidelines)
  - [Dependencies](#dependencies)
    - [Dev Dependencies](#dev-dependencies)
  - [Related Projects](#related-projects)
  - [License](#license)


## Introduction

**p99** is a lightweight, low-overhead library designed for generating real-time performance percentiles in high-frequency or latency-sensitive environments.

**p99.Zig** is the **Zig** implementation.


## How It Works

`p99.Zig` uses a fixed-size, zero-allocation logarithmic histogram with exactly 64 buckets.

Each bucket represents a power-of-two range of nanoseconds:
- Bucket `0` represents `[0, 1]` nanoseconds;
- Bucket `1` represents `[2, 3]` nanoseconds;
- Bucket `2` represents `[4, 7]` nanoseconds;
- ...
- Bucket `63` represents `[2^63, 2^64 - 1]` nanoseconds.

Finding the bucket index is extremely fast and branchless, implemented using the CPU's count leading zeros instruction (`@clz`).

When querying percentiles (e.g., P50, P99), the library performs linear interpolation within the target bucket to approximate the duration with high accuracy.


## Installation

The recommended way to add `p99.Zig` to your project is using the `zig fetch` command. Run the following in your project root:

```bash
zig fetch --save https://github.com/synesissoftware/p99.Zig/archive/refs/tags/v0.0.1.tar.gz
```

This will automatically download the package, compute its hash, and add it to your `build.zig.zon` dependencies:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .p99 = .{
            .url = "https://github.com/synesissoftware/p99.Zig/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "1220...", // Automatically calculated by zig fetch
        },
    },
}
```

Then, expose the dependency in your `build.zig`:

```zig
const p99_dep = b.dependency("p99", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("p99", p99_dep.module("p99"));
```


## Minimal Example

Here is a minimal example demonstrating how to use `p99.Zig`:

```zig
const std = @import("std");
const p99 = @import("p99");

pub fn main(init: std.process.Init) !void {
    var buffer: [4096]u8 = undefined;
    var stdout_impl = std.Io.File.stdout().writer(init.io, &buffer);
    const stdout = &stdout_impl.interface;

    var h = p99.Histogram{};

    // Push events (durations in nanoseconds)
    _ = h.pushEventTimeNs(100);
    _ = h.pushEventTimeNs(250);
    _ = h.pushEventTimeNs(500);
    _ = h.pushEventTimeNs(1000);
    _ = h.pushEventTimeNs(5000);

    // Query percentiles
    const p50 = h.valueAtP50().?;
    const p99_val = h.valueAtP99().?;

    try stdout.print("P50: {d} ns\n", .{p50});
    try stdout.print("P99: {d} ns\n", .{p99_val});

    try stdout.flush();
}
```


## Project Information


### Where to get help

[GitHub Page](https://github.com/synesissoftware/p99.Zig "GitHub Page")


### Contribution guidelines

Defect reports, feature requests, and pull requests are welcome on https://github.com/synesissoftware/p99.Zig.


### Dependencies

**p99.Zig** has no (non-development) dependencies beyond the Zig standard library.


#### Dev Dependencies

**p99.Zig** has no development dependencies beyond the Zig standard library.


### Related Projects

Other implementations of the **p99** specification include:

* [**p99** (C)](https://github.com/synesissoftware/p99);
* [**p99.Go** (Go)](https://github.com/synesissoftware/p99.Go);
* [**p99.Python** (Python)](https://github.com/synesissoftware/p99.Python);
* [**p99.Rust** (Rust)](https://github.com/synesissoftware/p99.Rust).


### License

**p99.Zig** is released under the 3-clause BSD license. See [LICENSE](./LICENSE) for details.

<!-- ########################### end of file ########################### -->
