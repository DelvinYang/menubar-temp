import IOKit

enum SMCError: Error, CustomStringConvertible {
    case connectionFailed(String)
    case ioKit(kern_return_t)
    case firmware(UInt8)
    case invalidKey(String)

    var description: String {
        switch self {
        case .connectionFailed(let message): return message
        case .ioKit(let code): return "IOKit error: 0x\(String(code, radix: 16))"
        case .firmware(let code): return "SMC firmware error: 0x\(String(code, radix: 16))"
        case .invalidKey(let key): return "Invalid SMC key: \(key)"
        }
    }
}

struct SMCParamStruct {
    typealias Bytes32 = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes32 = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct SMCValue {
    let key: String
    let bytes: [UInt8]
    let size: UInt32
    let type: String
}

final class SMCConnection {
    private let connection: io_connect_t

    init() throws {
        var iterator: io_iterator_t = 0
        defer { IOObjectRelease(iterator) }

        let match = IOServiceMatching("AppleSMC")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == kIOReturnSuccess else {
            throw SMCError.connectionFailed("Failed to find AppleSMC service")
        }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            throw SMCError.connectionFailed("AppleSMC service is not available")
        }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard result == kIOReturnSuccess else {
            throw SMCError.ioKit(result)
        }

        connection = conn
    }

    deinit {
        IOServiceClose(connection)
    }

    func readKey(_ key: String) throws -> SMCValue {
        let (param, info) = try fetchKeyInfo(key)
        var readParam = param
        readParam.keyInfo.dataSize = info.keyInfo.dataSize
        readParam.data8 = 5 // kSMCUserClientReadBytes
        let output = try call(readParam)
        try checkFirmware(output.result)
        let rawBytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.keyInfo.dataSize))) }
        return SMCValue(
            key: key,
            bytes: rawBytes,
            size: info.keyInfo.dataSize,
            type: decodeType(info.keyInfo.dataType)
        )
    }

    var temperatureKeys: [String] {
        get throws {
            let keyCount = try readKey("#KEY").uint32
            var keys: [String] = []
            keys.reserveCapacity(Int(min(keyCount, 1024)))

            for index in 0..<keyCount {
                var input = SMCParamStruct()
                input.data8 = 8 // kSMCUserClientReadIndex
                input.data32 = index
                guard let output = try? call(input) else { continue }
                let key = fourCharString(output.key)
                if key.first == "T" {
                    keys.append(key)
                }
            }

            return keys.sorted()
        }
    }

    func readTemperature() throws -> (key: String, temperature: Double)? {
        let candidates = ["Te05", "Te09", "Te0H", "Te0S", "Tp0X", "Tg0D", "TCMz"]
        for key in candidates {
            guard let value = try? readKey(key), value.type == "flt " else { continue }
            let temp = value.temperature
            if temp > 10 && temp < 120 {
                return (key, temp)
            }
        }
        return nil
    }

    var hasFan: Bool {
        (try? readKey("FNum"))?.uint32 ?? 0 > 0
    }

    private func fetchKeyInfo(_ key: String) throws -> (SMCParamStruct, SMCParamStruct) {
        var input = SMCParamStruct()
        input.key = try fourCharCode(key)
        input.data8 = 9 // kSMCUserClientReadKeyInfo
        let output = try call(input)
        try checkFirmware(output.result)
        return (input, output)
    }

    private func call(_ input: SMCParamStruct) throws -> SMCParamStruct {
        var input = input
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<SMCParamStruct>.stride, &output, &outputSize)
        guard result == kIOReturnSuccess else {
            throw SMCError.ioKit(result)
        }
        return output
    }
}

extension SMCValue {
    var uint32: UInt32 {
        guard bytes.count >= 4 else { return 0 }
        return bytes.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    var temperature: Double {
        if type == "sp78" && bytes.count >= 2 {
            let raw = Int16(bigEndian: bytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) })
            return Double(raw) / 256.0
        }
        if type == "flt " && bytes.count >= 4 {
            return Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) })
        }
        return 0
    }
}

private func checkFirmware(_ result: UInt8) throws {
    if result != 0 {
        throw SMCError.firmware(result)
    }
}

private func fourCharCode(_ key: String) throws -> UInt32 {
    guard key.utf8.count == 4 else { throw SMCError.invalidKey(key) }
    return key.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
}

private func fourCharString(_ value: UInt32) -> String {
    let chars = [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
    return String(bytes: chars, encoding: .ascii) ?? "????"
}

private func decodeType(_ value: UInt32) -> String {
    let chars = [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
    return String(bytes: chars, encoding: .ascii) ?? "????"
}
