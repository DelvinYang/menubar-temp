import Foundation

final class NetworkMonitor {
    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastTime: Date = .distantPast

    struct Speed {
        let upload: Double
        let download: Double
    }

    var speed: Speed? {
        let current = readBytes()
        let now = Date()

        guard lastTime != .distantPast else {
            lastRx = current.rx
            lastTx = current.tx
            lastTime = now
            return nil
        }

        let interval = now.timeIntervalSince(lastTime)
        guard interval > 0 else { return nil }

        let downSpeed = Double(current.rx - lastRx) / interval
        let upSpeed = Double(current.tx - lastTx) / interval

        lastRx = current.rx
        lastTx = current.tx
        lastTime = now

        return Speed(upload: upSpeed, download: downSpeed)
    }

    func reset() {
        lastTime = .distantPast
    }

    private func readBytes() -> (rx: UInt64, tx: UInt64) {
        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let start = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var ptr = start
        while true {
            let addr = ptr.pointee
            let name = String(cString: addr.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("enp") {
                if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalRx += UInt64(data.pointee.ifi_ibytes)
                    totalTx += UInt64(data.pointee.ifi_obytes)
                }
            }
            guard let next = addr.ifa_next else { break }
            ptr = next
        }

        return (totalRx, totalTx)
    }
}

func formatSpeed(_ bytesPerSec: Double) -> String {
    if bytesPerSec >= 1_000_000_000 {
        return String(format: "%.1f GB/s", bytesPerSec / 1_000_000_000)
    } else if bytesPerSec >= 1_000_000 {
        return String(format: "%.1f MB/s", bytesPerSec / 1_000_000)
    } else if bytesPerSec >= 1_000 {
        return String(format: "%.0f KB/s", bytesPerSec / 1_000)
    } else {
        return String(format: "%.0f B/s", bytesPerSec)
    }
}
