import Foundation

@MainActor
enum ProbeTimer {
    /// Release and recovery timers must also run during menu tracking/modal dialogs.
    static func schedule(withTimeInterval interval: TimeInterval, repeats: Bool,
                         block: @escaping @Sendable (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
