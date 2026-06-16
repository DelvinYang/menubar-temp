import Foundation
import SystemConfiguration

final class NetworkMonitor {
    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastTime: Date = .distantPast
    private var reachability: SCNetworkReachability?

    struct Speed {
        let upload: Double
        let download: Double
    }

    init() {
        setupReachability()
    }

    deinit {
        if let reachability {
            SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        }
    }

    private func setupReachability() {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        reachability = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
            }
        }
        guard let reachability else { return }

        var context = SCNetworkReachabilityContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard SCNetworkReachabilitySetCallback(reachability, { _, flags, info in
            guard let info else { return }
            let monitor = Unmanaged<NetworkMonitor>.fromOpaque(info).takeUnretainedValue()
            if !flags.contains(.reachable) {
                monitor.reset()
            }
        }, &context) else { return }

        SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.global(qos: .background))
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

        guard current.rx >= lastRx, current.tx >= lastTx else {
            lastRx = current.rx
            lastTx = current.tx
            lastTime = now
            return nil
        }

        let downSpeed = Double(current.rx - lastRx) / interval
        let upSpeed = Double(current.tx - lastTx) / interval

        let maxSpeed: Double = 2_000_000_000
        if downSpeed > maxSpeed || upSpeed > maxSpeed {
            lastRx = current.rx
            lastTx = current.tx
            lastTime = now
            return nil
        }

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
