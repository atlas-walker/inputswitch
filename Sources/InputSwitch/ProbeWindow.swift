import AppKit
import IOBluetooth

@MainActor
final class ProbeWindow: NSWindowController, NSWindowDelegate {
    let probe = ClassicHIDProbe()
    private let devices = NSPopUpButton()
    private var paired: [IOBluetoothDevice] = []
    private let connectButton = NSButton(title: "Conectar HID", target: nil, action: nil)
    private let incomingButton = NSButton(title: "Esperar al Mac personal", target: nil, action: nil)
    private var testButtons: [NSButton] = []
    private let output = NSTextView()
    private let startButton = NSButton(title: "Iniciar prueba SDP", target: nil, action: nil)

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "InputSwitch · Prueba Bluetooth"
        super.init(window: window)
        window.delegate = self
        window.center()
        let intro = NSTextField(wrappingLabelWithString: "Cierra KeyPad y otras apps de teclado Bluetooth antes de iniciar. Esta prueba publica un servicio temporal y verifica los canales HID. El teclado y el trackpad siguen en This Mac.")
        let stop = NSButton(title: "Detener", target: self, action: #selector(stopProbe))
        let copy = NSButton(title: "Copiar diagnóstico", target: self, action: #selector(copyReport))
        startButton.target = self
        startButton.action = #selector(startProbe)
        let buttons = NSStackView(views: [startButton, stop, copy])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        let refresh = NSButton(title: "Actualizar dispositivos", target: self, action: #selector(refreshDevices))
        devices.target = self
        devices.action = #selector(selectDevice)
        connectButton.target = self
        connectButton.action = #selector(connectDevice)
        let pairRow = NSStackView(views: [devices, refresh, connectButton])
        pairRow.spacing = 10
        incomingButton.target = self
        incomingButton.action = #selector(waitForIncoming)
        incomingButton.isEnabled = false
        let labels = ["Probar tecla A", "Mover puntero", "Probar clic"]
        testButtons = labels.enumerated().map { index, title in
            let button = NSButton(title: title, target: self, action: #selector(runTest(_:)))
            button.tag = index
            button.isEnabled = false
            return button
        }
        let testRow = NSStackView(views: testButtons)
        testRow.spacing = 10
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        output.isEditable = false
        output.isSelectable = true
        output.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        output.autoresizingMask = [.width]
        output.textContainer?.widthTracksTextView = true
        scroll.documentView = output
        let stack = NSStackView(views: [intro, buttons, pairRow, incomingButton, testRow, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])
        probe.onChange = { [weak self] in
            guard let self else { return }
            self.output.string = self.probe.report
            self.startButton.isEnabled = !self.probe.active
            self.connectButton.isEnabled = self.probe.active && self.probe.canSelectDevice && self.devices.indexOfSelectedItem > 0
            self.incomingButton.isEnabled = self.connectButton.isEnabled
            self.devices.isEnabled = self.probe.canSelectDevice
            self.testButtons.forEach { $0.isEnabled = self.probe.ready }
        }
        devices.addItem(withTitle: "Selecciona tu Mac emparejado")
        connectButton.isEnabled = false
        probe.log("Listo. Pulsa Iniciar prueba SDP cuando hayas cerrado otras apps HID.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    @objc private func refreshDevices() {
        guard probe.canSelectDevice else { return }
        probe.select(nil)
        paired = probe.pairedDevices
        devices.removeAllItems()
        devices.addItem(withTitle: "Selecciona tu Mac emparejado")
        for (index, device) in paired.enumerated() {
            devices.addItem(withTitle: "\(index + 1). \(device.name ?? "Dispositivo sin nombre")")
        }
        connectButton.isEnabled = false
        probe.log("Lista actualizada. Si tu Mac no aparece, empareja ambos desde Ajustes del Sistema > Bluetooth.")
    }
    @objc private func selectDevice() {
        guard probe.canSelectDevice else { return }
        let index = devices.indexOfSelectedItem - 1
        guard paired.indices.contains(index) else { probe.select(nil); return }
        probe.select(paired[index])
        connectButton.isEnabled = probe.active && probe.canSelectDevice
        incomingButton.isEnabled = connectButton.isEnabled
    }
    @objc private func waitForIncoming() { probe.waitForIncoming() }
    @objc private func connectDevice() { probe.connect() }
    @objc private func runTest(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = sender.title
        alert.informativeText = "La acción se enviará al Mac seleccionado en 3 segundos. Deja abierta una ventana de texto vacía; para el clic, coloca el puntero sobre una zona sin botones ni enlaces. No se captura tu teclado."
        alert.addButton(withTitle: "Enviar prueba")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn { probe.test(sender.tag) }
    }
    @objc private func startProbe() { probe.start() }
    @objc private func stopProbe() { probe.stop() }
    @objc private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(probe.report, forType: .string)
    }
    func windowWillClose(_ notification: Notification) { probe.stop() }
}
