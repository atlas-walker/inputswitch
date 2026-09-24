import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var showingDetails = false

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
        let details = NSMenuItem(title: "Prueba de ejecución…", action: #selector(showDetails), keyEquivalent: "")
        details.target = self
        menu.addItem(details)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir de InputSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApplication.shared
        menu.addItem(quit)
        statusItem.menu = menu
        showDetails()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDetails()
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
        Hito 1 · Prueba de distribución

        Encontrarás el menú de InputSwitch arriba, en la barra de menús, junto al texto «This Mac».

        Versión: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "desconocida")
        Sistema: \(ProcessInfo.processInfo.operatingSystemVersionString)

        El teclado y el trackpad permanecen en This Mac. Esta build todavía no captura entrada ni conecta por Bluetooth.

        Para validar el hito, abre el ZIP distribuido en el Mac del trabajo con tu usuario habitual y comprueba que aparece este mensaje. Después selecciona Salir de InputSwitch.
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
