import Foundation
import IOBluetooth

@main
struct ProtocolTests {
    static func main() {
        // Parse HID short items independently of report encoder; verify descriptor agrees with wire lengths.
        var offset = 0, reportID = 0, size = 0, count = 0
        var inputBits: [Int:Int] = [:], outputBits: [Int:Int] = [:]
        while offset < HIDDescriptor.bytes.count {
            let prefix = HIDDescriptor.bytes[offset]
            offset += 1
            let length = [0,1,2,4][Int(prefix & 3)]
            precondition(offset + length <= HIDDescriptor.bytes.count)
            let value = (0..<length).reduce(0) { $0 | Int(HIDDescriptor.bytes[offset + $1]) << ($1 * 8) }
            offset += length
            switch prefix & 0xFC {
            case 0x84: reportID = value
            case 0x74: size = value
            case 0x94: count = value
            case 0x80: inputBits[reportID, default: 0] += size * count
            case 0x90: outputBits[reportID, default: 0] += size * count
            default: break
            }
        }
        precondition(inputBits == [1:64,2:40])
        precondition(outputBits == [1:8])
        precondition(HIDReports.keyboardNeutral.count == 1 + inputBits[1]! / 8)
        precondition(HIDReports.mouseNeutral.count == 1 + inputBits[2]! / 8)
        precondition(HIDReports.response(to: [0x60]) == [0xA0,1])
        precondition(HIDReports.response(to: [0x70]) == [3])
        precondition(HIDReports.response(to: [0x71]) == [0])
        precondition(HIDReports.response(to: [0x41,1], keyboard: HIDReports.keyA) == HIDReports.packet(HIDReports.keyA))
        precondition(HIDReports.response(to: [0x49,1,8,0]) == [4])
        precondition(HIDReports.response(to: [0x49,1,9,0]) == HIDReports.packet(HIDReports.keyboardNeutral))
        precondition(HIDReports.response(to: [0x41,3]) == [2])
        precondition(HIDReports.response(to: [0x52,1,3]) == [0])
        precondition(HIDReports.response(to: [0x52,2,3]) == [4])
        precondition(HIDReports.response(to: []) == [4])
        for header in UInt8.min...UInt8.max {
            for length in 0...8 {
                _ = HIDReports.response(to: [header] + Array(repeating: 255, count: length))
            }
        }
        // Parse full SDP dictionary through Apple's parser without publishing to the radio.
        let protocolList = IOBluetoothSDPDataElement(elementValue: (HIDDescriptor.service["0004"] as! NSObject))!
        let protocols = protocolList.getArrayValue()!
        let l2cap = (protocols[0] as! IOBluetoothSDPDataElement).getArrayValue()!
        precondition((l2cap[1] as! IOBluetoothSDPDataElement).getNumberValue() == 0x11)
        let descriptorList = IOBluetoothSDPDataElement(elementValue: (HIDDescriptor.service["0206"] as! NSObject))!.getArrayValue()!
        let descriptor = (descriptorList[0] as! IOBluetoothSDPDataElement).getArrayValue()!
        precondition((descriptor[1] as! IOBluetoothSDPDataElement).getDataValue() == Data(HIDDescriptor.bytes))
        print("PASS: HID descriptor sizes, HIDP requests/malformed input, SDP encoding and PSM decoding")
    }
}
