import Foundation
import MachO

final class MemoryMonitor {
    func usage() -> Double {
        let host = mach_host_self()
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return -1 }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let totalPages = ProcessInfo.processInfo.physicalMemory / pageSize
        let used = totalPages
            - UInt64(max(0, stats.free_count))
            - UInt64(stats.external_page_count)
            - UInt64(stats.purgeable_count)
        return Double(used) / Double(totalPages) * 100
    }
}
