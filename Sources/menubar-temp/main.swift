import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var netItem: NSStatusItem!
    private var tempItem: NSStatusItem!
    private var cpuItem: NSStatusItem!
    private var memItem: NSStatusItem!
    private var netView: TwoLineView!
    private var tempView: TwoLineView!
    private var cpuView: TwoLineView!
    private var memView: TwoLineView!
    private var timer: Timer?
    private let smc: SMCConnection
    private let cpuMon = CpuMonitor()
    private let memMon = MemoryMonitor()
    private let netMon = NetworkMonitor()
    private var fanItem: NSStatusItem!
    private var fanRunning = false
    private let fanPidPath = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/网络工具和服务器指南文档/mac-fanctl/auto-temp-fan.pid")

    override init() {
        self.smc = try! SMCConnection()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if #available(macOS 13, *) {
            try? SMAppService.mainApp.register()
        }

        // Status items stack right-to-left; first created = farthest right.
        // Desired order (left→right): net, temp, cpu, mem
        // Create order (right→left): mem, cpu, temp, net

        memItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        memView = TwoLineView(item: memItem, mode: .center, topFontSize: 11, bottomFontSize: 9)
        memView.top = "⟳"
        memView.bottom = "MEM"
        setMenu(memItem, title: "Memory")

        cpuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        cpuView = TwoLineView(item: cpuItem, mode: .center, topFontSize: 11, bottomFontSize: 9)
        cpuView.top = "⟳"
        cpuView.bottom = "CPU"
        setMenu(cpuItem, title: "CPU Usage")

        fanItem = NSStatusBar.system.statusItem(withLength: 26)
        fanItem.button?.imagePosition = .imageOnly
        setMenu(fanItem, title: "Fan Controller")
        updateFanIcon(running: false)

        tempItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        tempView = TwoLineView(item: tempItem, mode: .center, topFontSize: 11, bottomFontSize: 9)
        tempView.top = "⟳"
        tempView.bottom = "TEM"
        setMenu(tempItem, title: "CPU Temperature")

        netItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        netView = TwoLineView(item: netItem, mode: .arrowSpeed(maxValueChars: 9, prefixTop: "↑", prefixBottom: "↓"))
        netView.top = "0 B/s"
        netView.bottom = "0 B/s"
        setMenu(netItem, title: "Network")

        _ = cpuMon.usage()
        _ = memMon.usage()
        _ = netMon.speed
        updateAll()
        timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(updateAll), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc func updateAll() {
        updateTemperature()
        updateFan()
        updateCpu()
        updateMemory()
        updateNetwork()
    }

    private func updateTemperature() {
        if let result = try? smc.readTemperature() {
            tempView.top = String(format: "%.0f°C", result.temperature)
            setMenuTitle(tempItem, "CPU: \(result.key) \(tempView.top)")
        } else {
            tempView.top = "N/A"
            setMenuTitle(tempItem, "CPU: N/A")
        }
    }

    private func updateCpu() {
        let pct = cpuMon.usage()
        if pct >= 0 {
            cpuView.top = String(format: "%.0f%%", pct)
            setMenuTitle(cpuItem, "CPU: \(cpuView.top)")
        }
    }

    private func updateMemory() {
        let pct = memMon.usage()
        if pct >= 0 {
            memView.top = String(format: "%.0f%%", pct)
            setMenuTitle(memItem, "Memory: \(memView.top)")
        }
    }

    private func updateNetwork() {
        if let speed = netMon.speed {
            netView.top = formatSpeed(speed.upload)
            netView.bottom = formatSpeed(speed.download)
            setMenuTitle(netItem, "↑ \(formatSpeed(speed.upload))  ↓ \(formatSpeed(speed.download))")
        }
    }

    private func updateFan() {
        let running = isFanControllerRunning()
        if running != fanRunning {
            fanRunning = running
            updateFanIcon(running: running)
            setMenuTitle(fanItem, "Fan: \(running ? "Running" : "Stopped")")
        }
    }

    private func updateFanIcon(running: Bool) {
        let name = running ? "fan.fill" : "fan"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        fanItem.button?.image = img.withSymbolConfiguration(config)
    }

    private func isFanControllerRunning() -> Bool {
        guard let pidStr = try? String(contentsOfFile: fanPidPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = pid_t(pidStr) else {
            return false
        }
        return kill(pid, 0) == 0
    }

    @objc func quit() {
        timer?.invalidate()
        NSApp.terminate(nil)
    }

    private func setMenu(_ item: NSStatusItem, title: String) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
    }

    private func setMenuTitle(_ item: NSStatusItem, _ title: String) {
        if let menu = item.menu, menu.items.count >= 1 {
            menu.items[0].title = title
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
