import Foundation
import IOBluetooth

/// One callback target per attempt: late completions cannot resume another session.
@MainActor
final class ProbeBaseband: NSObject {
    var completion: ((IOBluetoothDevice?, IOReturn) -> Void)?

    @objc func connectionComplete(_ device: IOBluetoothDevice?, status: IOReturn) {
        completion?(device, status)
        completion = nil
    }
}
