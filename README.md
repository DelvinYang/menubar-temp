# menubar-temp

A lightweight macOS menu bar monitor for CPU temperature, CPU usage, memory usage, and network speed.

## Features

- **CPU Temperature** — reads the E-core cluster sensor via SMC (Apple Silicon only)
- **CPU Usage** — percentage based on `host_cpu_load_info`
- **Memory Usage** — percentage based on `vm_statistics64` (matches Activity Monitor)
- **Network Speed** — upload/download speed via `getifaddrs`

All four appear as separate menu bar items. The app has no dock icon.

## Build

```sh
swift build -c release
```

## Run

```sh
.open .build/release/menubar-temp.app
```

Or copy the `.app` bundle to `/Applications`.

The app auto-registers as a login item on first launch (macOS 13+).

## Menu Bar Layout (left → right)

```
NET | TEMP | CPU | MEM
```

- **NET**: ↑ upload / ↓ download (fixed-width arrow + value)
- **TEMP**: CPU temperature in °C
- **CPU**: CPU usage %
- **MEM**: Memory usage %

## Requirements

- macOS 14+
- Apple Silicon (M1–M4) for SMC temperature reading
- No sandbox, no special entitlements

## Files

```
Package.swift         — SwiftPM manifest
Sources/
  menubar-temp/
    main.swift        — AppDelegate, update loop
    StatusItemView.swift — TwoLineView (NSImage-based menu bar renderer)
    SMC.swift         — AppleSMC IOKit connection + temperature reader
    CpuMonitor.swift  — CPU usage via Mach host_statistics
    MemoryMonitor.swift — Memory usage via vm_statistics64
    NetworkMonitor.swift — Network speed via getifaddrs
```
