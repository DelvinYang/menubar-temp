# menubar-temp

A lightweight macOS menu bar monitor for CPU temperature, CPU usage, memory usage, and network speed, with integrated fan controller status.

## Features

- **CPU Temperature** — reads the E-core cluster sensor via SMC (Apple Silicon only)
- **CPU Usage** — percentage based on `host_cpu_load_info`
- **Memory Usage** — percentage based on `vm_statistics64` (matches Activity Monitor)
- **Network Speed** — upload/download speed via `getifaddrs`
- **Fan Controller Status** — fan icon in the TEMP item shows the real-time status of [mac-fanctl](https://github.com/DelvinYang/mac-fanctl):
  - Controller not running → outline icon (static)
  - Controller running, temp ≤ 50°C → filled icon (static)
  - Controller running, temp > 50°C → filled icon (rotating)

All items appear as separate menu bar entries. The app has no dock icon.

## Build

```sh
swift build -c release
```

## Run

```sh
open .build/release/menubar-temp.app
```

Or copy the `.app` bundle to `/Applications`.

The app auto-registers as a login item on first launch (macOS 13+).

## Menu Bar Layout (left → right)

```
NET | TEMP+fan | CPU | MEM
```

- **NET**: ↑ upload / ↓ download (fixed-width arrow + value)
- **TEMP**: CPU temperature in °C + fan icon linked to [mac-fanctl](https://github.com/DelvinYang/mac-fanctl)
- **CPU**: CPU usage %
- **MEM**: Memory usage %

## Fan Controller Integration

The fan icon in the TEMP item reads the PID file written by the [mac-fanctl](https://github.com/DelvinYang/mac-fanctl) PI controller (`auto-temp-fan.pid`). When the controller's process is alive, the icon fills. When the CPU temperature exceeds 50°C (the controller's default target), the icon rotates to indicate active cooling.

Build and run the controller:

```sh
cd /path/to/mac-fanctl
swift build
sudo scripts/auto-temp-fan.py --target 50 --max-rpm 3000
```

## Requirements

- macOS 14+
- Apple Silicon (M1–M4) for SMC temperature reading
- [mac-fanctl](https://github.com/DelvinYang/mac-fanctl) (optional, for fan status display)
- No sandbox, no special entitlements

## Files

```
Package.swift              — SwiftPM manifest
Sources/menubar-temp/
  main.swift               — AppDelegate, update loop, fan status check
  StatusItemView.swift     — TwoLineView (NSImage-based menu bar renderer)
  SMC.swift                — AppleSMC IOKit connection + temperature reader
  CpuMonitor.swift         — CPU usage via Mach host_statistics
  MemoryMonitor.swift      — Memory usage via vm_statistics64
  NetworkMonitor.swift     — Network speed via getifaddrs
```

## License

This project is licensed under the **MIT License**, with the additional restriction that **commercial use is not permitted**. You may freely use, modify, and share this software for personal, non-commercial purposes. If you make changes, please fork the repository rather than pushing directly to this one.
