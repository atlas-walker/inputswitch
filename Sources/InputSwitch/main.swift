import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var showingDetails = false
    private var probeWindow: ProbeWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "InputSwitch · This Mac")
        statusItem.button?.title = " This Mac"
        let menu = NSMenu()
        let local = NSMenuItem(title: "This Mac", action: nil, keyEquivalent: "")
        local.state = .on
        menu.addItem(local)
        let remote = NSMenuItem(title: "Andrés PC — pendiente de prueba Bluetooth", action: nil, keyEquivalent: "")
        menu.addItem(remote)
        menu.addItem(.separator())
        let bluetooth = NSMenuItem(title: "Prueba Bluetooth…", action: #selector(showBluetooth), keyEquivalent: "")
        bluetooth.target = self
        menu.addItem(bluetooth)
        let details = NSMenuItem(title: "Prueba de ejecución…", action: #selector(showDetails), keyEquivalent: "")
        details.target = self
        menu.addItem(details)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir de InputSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApplication.shared
        menu.addItem(quit)
        statusItem.menu = menu
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(stopBluetooth), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(stopBluetooth), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        showBluetooth()
    }

    func applicationWillTerminate(_ notification: Notification) { probeWindow?.probe.stop() }
    @objc private func stopBluetooth() { probeWindow?.probe.stop() }
    @objc private func showBluetooth() {
        if probeWindow == nil { probeWindow = ProbeWindow() }
        NSApplication.shared.activate(ignoringOtherApps: true)
        probeWindow?.showWindow(nil)
        probeWindow?.window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showBluetooth()
        return true
    }

    @objc private func showDetails() {
        guard !showingDetails else { return }
        showingDetails = true
        defer { showingDetails = false }
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "InputSwitch se ha abierto correctamente"
        alert.informativeText = """
        Hito 1 superado · Prototipo Bluetooth

        Encontrarás el menú de InputSwitch arriba, en la barra de menús, junto al texto «This Mac».

        Versión: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "desconocida")
        Sistema: \(ProcessInfo.processInfo.operatingSystemVersionString)

        El teclado y el trackpad permanecen en This Mac. Esta build permite comprobar la publicación de un servicio Bluetooth HID temporal. No captura entrada global; solo envía acciones fijas desde los botones de prueba.

        Continúa desde Prueba Bluetooth y comparte el diagnóstico junto con el resultado observado en el Mac personal.
        """
        alert.addButton(withTitle: "Entendido")
        alert.runModal()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
