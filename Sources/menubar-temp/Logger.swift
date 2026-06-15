import os
import Foundation

let log = Logger(subsystem: "com.shuqishen.menubar-temp", category: "general")

private let crashLogDir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs/menubar-temp")

private let onException: @convention(c) (NSException) -> Void = { exception in
    let info = [
        "name: \(exception.name.rawValue)",
        "reason: \(exception.reason ?? "nil")",
        "callStack: \(exception.callStackSymbols.joined(separator: "\n"))",
    ]
    let text = "=== Uncaught Exception ===\n\(info.joined(separator: "\n"))\n"
    let path = "\(crashLogDir)/exception_\(Int(Date().timeIntervalSince1970)).log"
    try? text.write(toFile: path, atomically: true, encoding: .utf8)
}

private let onSignal: @convention(c) (Int32) -> Void = { s in
    let msg = "MENUBAR-TEMP CRASH signal=\(s)\n"
    let data = msg.data(using: .utf8)!
    _ = data.withUnsafeBytes { write(STDERR_FILENO, $0.baseAddress, $0.count) }
    signal(s, SIG_DFL)
    raise(s)
}

func setupCrashHandler() {
    try? FileManager.default.createDirectory(atPath: crashLogDir, withIntermediateDirectories: true)
    NSSetUncaughtExceptionHandler(onException)
    let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP]
    for sig in signals {
        signal(sig, onSignal)
    }
}
