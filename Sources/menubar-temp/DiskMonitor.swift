import Foundation

final class DiskMonitor {
    func usage() -> Double {
        var stat = statfs()
        guard statfs("/", &stat) == 0 else { return -1 }
        let total = UInt64(stat.f_blocks) * UInt64(stat.f_bsize)
        let free = UInt64(stat.f_bfree) * UInt64(stat.f_bsize)
        let used = total - free
        guard total > 0 else { return -1 }
        return Double(used) / Double(total)
    }
}
