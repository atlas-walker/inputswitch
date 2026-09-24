import Foundation
import IOBluetooth

/// One asynchronous write at a time, bounded backlog, buffer retained until callback.
/// No Bluetooth I/O occurs in an input callback (there is no input capture yet).
@MainActor
final class ProbeChannel: NSObject, @preconcurrency IOBluetoothL2CAPChannelDelegate {
    var channel: IOBluetoothL2CAPChannel?
    var onOpen: ((IOReturn) -> Void)?
    var onClose: (() -> Void)?
    var onData: (([UInt8]) -> Void)?
    var onError: ((String) -> Void)?
    private var queue: [[UInt8]] = []
    private var pending: NSMutableData?
    private var watchdog: Timer?
    private var closeDeadline: Timer?
    private var finishing = false
    private(set) var closed = false
    var hasPending: Bool { pending != nil }
    var idle: Bool { pending == nil && queue.isEmpty }

    func send(_ bytes: [UInt8]) {
        guard !closed, let channel else { return }
        guard bytes.count <= Int(channel.outgoingMTU), queue.count < 16 else {
            onError?("MTU insuficiente o cola de escritura llena."); return
        }
        queue.append(bytes)
        pump()
    }
    private func pump() {
        guard !closed, pending == nil, !queue.isEmpty, let channel else { return }
        let bytes = queue.removeFirst()
        let buffer = NSMutableData(data: Data(bytes))
        pending = buffer
        let result = channel.writeAsync(buffer.mutableBytes, length: UInt16(buffer.length), refcon: nil)
        if result != kIOReturnSuccess {
            pending = nil
            onError?(String(format: "writeAsync: 0x%08X", result)); return
        }
        watchdog = ProbeTimer.schedule(withTimeInterval: 2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.onError?("Timeout de escritura Bluetooth (2 s).") }
        }
    }
    func finishWithNeutral() {
        guard !closed else { return }
        queue = [HIDReports.packet(HIDReports.keyboardNeutral), HIDReports.packet(HIDReports.mouseNeutral)]
        finishing = true
        pump()
        closeDeadline = ProbeTimer.schedule(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }
    func close() {
        closed = true
        closeDeadline?.invalidate()
        queue.removeAll()
        watchdog?.invalidate()
        watchdog = nil
        // Keep pending until writeComplete. Owner retains retired writers with pending data.
        _ = channel?.close()
    }
    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        if closed { _ = l2capChannel?.close(); return }
        channel = l2capChannel
        onOpen?(error)
    }
    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        if !closed { closed = true; watchdog?.invalidate(); onClose?() }
    }
    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard !closed, let dataPointer else { return }
        guard dataLength > 0, dataLength <= 512 else { onError?("Mensaje HIDP fuera de límites."); return }
        onData?(Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength)))
    }
    func l2capChannelWriteComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        watchdog?.invalidate()
        watchdog = nil
        pending = nil
        guard !closed else { return }
        if error != kIOReturnSuccess { onError?(String(format: "writeComplete: 0x%08X", error)); return }
        if finishing && queue.isEmpty { close() } else { pump() }
    }
}
