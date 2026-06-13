import Foundation
import MachO

final class CpuMonitor {
    private var lastTotal: UInt64 = 0
    private var lastIdle: UInt64 = 0

    func usage() -> Double {
        var cpuLoad = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return -1 }

        let user = UInt64(cpuLoad.cpu_ticks.0)
        let system = UInt64(cpuLoad.cpu_ticks.1)
        let idle = UInt64(cpuLoad.cpu_ticks.2)
        let nice = UInt64(cpuLoad.cpu_ticks.3)
        let total = user + system + idle + nice

        guard lastTotal > 0 else {
            lastTotal = total
            lastIdle = idle
            return 0
        }

        let totalDelta = total - lastTotal
        let idleDelta = idle - lastIdle

        lastTotal = total
        lastIdle = idle

        guard totalDelta > 0 else { return 0 }
        return (1 - Double(idleDelta) / Double(totalDelta)) * 100
    }
}
