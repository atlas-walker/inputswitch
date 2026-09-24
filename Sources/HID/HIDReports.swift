import Foundation

enum HIDReports {
    static let keyboardNeutral: [UInt8] = [1,0,0,0,0,0,0,0,0]
    static let mouseNeutral: [UInt8] = [2,0,0,0,0,0]
    static let keyA: [UInt8] = [1,0,0,4,0,0,0,0,0]
    static let moveRight: [UInt8] = [2,0,30,0,0,0]
    static let leftDown: [UInt8] = [2,1,0,0,0,0]
    static func packet(_ report: [UInt8]) -> [UInt8] { [0xA1] + report }

    /// HIDP control requests. Feature/boot/unsupported requests get explicit errors.
    static func response(to data: [UInt8], keyboard: [UInt8] = keyboardNeutral, mouse: [UInt8] = mouseNeutral) -> [UInt8]? {
        guard let header = data.first else { return [0x04] }
        switch header {
        case 0x60: return data.count == 1 ? [0xA0,1] : [0x04] // GET_PROTOCOL
        case 0x71: return data.count == 1 ? [0x00] : [0x04] // report protocol
        case 0x70: return [0x03] // boot unsupported
        case 0x80: return data.count == 1 ? [0xA0,0] : [0x04]
        case 0x90: return data == [0x90,0] ? [0x00] : [0x03]
        case 0x41,0x49:
            guard data.count == (header == 0x49 ? 4 : 2) else { return [0x04] }
            let report: [UInt8]
            switch data[1] { case 1: report = keyboard; case 2: report = mouse; default: return [0x02] }
            if header == 0x49 {
                let size = Int(data[2]) | Int(data[3]) << 8
                guard size >= report.count else { return [0x04] }
            }
            return packet(report)
        case 0x52: return data.count == 3 && data[1] == 1 ? [0x00] : [0x04]
        case 0x10: return nil // HID_CONTROL NOP, no handshake
        case 0x11,0x12,0x13,0x14,0x15: return nil // handled by coordinator
        default: return [0x03]
        }
    }
}
