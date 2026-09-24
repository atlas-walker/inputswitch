import Foundation
import IOBluetooth

/// Independent HID report descriptor: keyboard ID 1, relative mouse ID 2.
/// Report protocol only; no boot protocol or multimedia keys advertised.
enum HIDDescriptor {
    static let bytes: [UInt8] = [
        0x05,0x01,0x09,0x06,0xA1,0x01,0x85,0x01,
        0x05,0x07,0x19,0xE0,0x29,0xE7,0x15,0x00,0x25,0x01,
        0x75,0x01,0x95,0x08,0x81,0x02,
        0x75,0x08,0x95,0x01,0x81,0x01,
        0x05,0x08,0x19,0x01,0x29,0x05,0x75,0x01,0x95,0x05,0x91,0x02,
        0x75,0x03,0x95,0x01,0x91,0x01,
        0x05,0x07,0x19,0x00,0x29,0x65,0x15,0x00,0x25,0x65,
        0x75,0x08,0x95,0x06,0x81,0x00,0xC0,
        0x05,0x01,0x09,0x02,0xA1,0x01,0x85,0x02,0x09,0x01,0xA1,0x00,
        0x05,0x09,0x19,0x01,0x29,0x03,0x15,0x00,0x25,0x01,
        0x75,0x01,0x95,0x03,0x81,0x02,0x75,0x05,0x95,0x01,0x81,0x01,
        0x05,0x01,0x09,0x30,0x09,0x31,0x09,0x38,
        0x15,0x81,0x25,0x7F,0x75,0x08,0x95,0x03,0x81,0x06,
        0x05,0x0C,0x0A,0x38,0x02,0x95,0x01,0x81,0x06,0xC0,0xC0
    ]
    static func uint(_ value: Int, size: Int = 2) -> [String: Any] {
        ["DataElementType": 1, "DataElementSize": size, "DataElementValue": value]
    }
    static func bool(_ value: Bool) -> [String: Any] {
        ["DataElementType": 5, "DataElementValue": NSNumber(value: value)]
    }
    static func uuid(_ value: UInt16) -> Data { Data([UInt8(value >> 8), UInt8(value & 255)]) }
    static var service: [String: Any] {
        [
            "LocalAttributes": ["Persistent": false],
            "0001": [uuid(0x1124)],
            "0004": [[uuid(0x0100), uint(0x11)], [uuid(0x0011)]],
            "0005": [uuid(0x1002)],
            "0006": [uint(0x656E), uint(0x006A), uint(0x0100)],
            "0009": [[uuid(0x1124), uint(0x0101)]],
            "000D": [[[uuid(0x0100), uint(0x13)], [uuid(0x0011)]]],
            "0100": "InputSwitch HID Probe",
            "0101": "Keyboard and relative mouse feasibility test",
            "0102": "InputSwitch",
            "0200": uint(0x0100), "0201": uint(0x0111),
            "0202": uint(0xC0, size: 1), "0203": uint(0, size: 1),
            "0204": bool(false), "0205": bool(false),
            "0206": [[uint(0x22, size: 1), ["DataElementType": 4, "DataElementValue": Data(bytes)]]],
            "0207": [[uint(0x0409), uint(0x0100)]],
            "0208": bool(false), "0209": bool(false),
            "020A": bool(false), "020C": uint(0x0C80),
            "020D": bool(false), "020E": bool(false)
        ]
    }
    /// Read the actual nested SDP elements, never infer allocation from publication success.
    static func interruptPSM(_ record: IOBluetoothSDPServiceRecord) -> UInt16? {
        guard let lists = record.getAttributeDataElement(0x000D)?.getArrayValue(),
              let protocols = (lists.first as? IOBluetoothSDPDataElement)?.getArrayValue(),
              let l2cap = (protocols.first as? IOBluetoothSDPDataElement)?.getArrayValue(),
              l2cap.count >= 2,
              let value = (l2cap[1] as? IOBluetoothSDPDataElement)?.getNumberValue() else { return nil }
        return value.uint16Value
    }
}
