import AppKit
import Darwin
import Foundation
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var netItem: NSStatusItem!
    private var tempItem: NSStatusItem!
    private var cpuItem: NSStatusItem!
    private var memItem: NSStatusItem!
    private var diskItem: NSStatusItem!
    private var netView: TwoLineView!
    private var tempView: TwoLineView!
    private var cpuView: TwoLineView!
    private var memView: TwoLineView!
    private var diskView: TwoLineView!
    private var timer: Timer?
    private let smc: SMCConnection
    private let cpuMon = CpuMonitor()
    private let memMon = MemoryMonitor()
    private let netMon = NetworkMonitor()
    private let diskMon = DiskMonitor()
    private var fanTimer: Timer?
    private var currentTemp: Double = 0
    private let fanTempThreshold: Double = 50
    private let hasFan: Bool

    override init() {
        let smc = try! SMCConnection()
        self.smc = smc
        self.hasFan = smc.hasFan
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if #available(macOS 13, *) {
            try? SMAppService.mainApp.register()
        }

        // Status items stack right-to-left; first created = farthest right.
        // Desired order (left→right): net, temp, cpu, mem, disk
        // Create order (right→left): disk, mem, cpu, temp, net

        diskItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        diskView = TwoLineView(item: diskItem, mode: .disk, topFontSize: 11, bottomFontSize: 9)
        diskView.top = "⟳"
        diskView.bottom = "DISK"
        setMenu(diskItem, title: "Disk")

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
        updateCpu()
        updateMemory()
        updateDisk()
        updateNetwork()
    }

    private func updateTemperature() {
        if let result = try? smc.readTemperature() {
            currentTemp = result.temperature
            tempView.top = String(format: "%.0f°C", result.temperature)
            setMenuTitle(tempItem, "CPU: \(result.key) \(tempView.top)")
        } else {
            currentTemp = 0
            tempView.top = "N/A"
            setMenuTitle(tempItem, "CPU: N/A")
        }
        if hasFan {
            let running = isFanControllerRunning()
            tempView.rightSymbolName = running ? "fan.fill" : "fan"
            if running {
                if fanTimer == nil { startFanAnimation() }
            } else {
                stopFanAnimation()
            }
        } else {
            tempView.rightSymbolName = nil
            stopFanAnimation()
        }
    }

    private func startFanAnimation() {
        fanTimer?.invalidate()
        tempView.fanAngle = 0
        fanTimer = Timer.scheduledTimer(timeInterval: 0.125, target: self, selector: #selector(fanTick), userInfo: nil, repeats: true)
        RunLoop.main.add(fanTimer!, forMode: .common)
    }

    private func stopFanAnimation() {
        fanTimer?.invalidate()
        fanTimer = nil
        tempView.fanAngle = 0
    }

    @objc private func fanTick() {
        if currentTemp > fanTempThreshold {
            tempView.fanAngle += .pi / 4
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

    private func updateDisk() {
        let pct = diskMon.usage()
        if pct >= 0 {
            diskView.fillValue = CGFloat(pct)
            diskView.top = String(format: "%.0f%%", pct * 100)
            setMenuTitle(diskItem, "Disk: \(diskView.top)")
        }
    }

    private func updateNetwork() {
        if let speed = netMon.speed {
            netView.top = formatSpeed(speed.upload)
            netView.bottom = formatSpeed(speed.download)
            setMenuTitle(netItem, "↑ \(formatSpeed(speed.upload))  ↓ \(formatSpeed(speed.download))")
        }
    }

    private func isFanControllerRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "auto-temp-fan"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    @objc func quit() {
        fanTimer?.invalidate()
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
