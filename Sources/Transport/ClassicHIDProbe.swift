import AppKit
import IOBluetooth

/// Publication is a separate gate from pairing, channels and real input.
/// This probe never captures or suppresses local input.
@MainActor
final class ClassicHIDProbe: NSObject {
    private var record: IOBluetoothSDPServiceRecord?
    private var notifications: [IOBluetoothUserNotification] = []
    private(set) var active = false
    private var lines: [String] = []
    private var selected: IOBluetoothDevice?
    private var controlChannel: ProbeChannel?
    private var interruptChannel: ProbeChannel?
    private var retired: [ProbeChannel] = []
    private var opened: Set<UInt16> = []
    private var connectionTimer: Timer?
    private var testTimer: Timer?
    private var generation = 0
    private var connecting = false
    private var wantsOutgoing = false
    private var phase = "sin conexión"
    private var basebandAttempts: [ProbeBaseband] = []
    private var encryptionTimer: Timer?
    private var attemptStarted: TimeInterval = 0
    private(set) var ready = false
    private var testing = false
    private var currentKeyboard = HIDReports.keyboardNeutral
    private var currentMouse = HIDReports.mouseNeutral

    var canSelectDevice: Bool { !connecting && controlChannel == nil && interruptChannel == nil }
    var pairedDevices: [IOBluetoothDevice] { (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? [] }

    func select(_ device: IOBluetoothDevice?) {
        guard !ready, canSelectDevice else {
            log("Detén la prueba antes de cambiar de receptor."); return
        }
        selected = device
        log(device == nil ? "Selección de receptor borrada." : "Receptor seleccionado explícitamente (identificador omitido).")
    }

    func connect() {
        guard active, canSelectDevice else { return }
        guard let selected, selected.isPaired() else {
            log("Selecciona primero el Mac personal ya emparejado en Ajustes de Bluetooth."); return
        }
        guard retired.count < 8, basebandAttempts.count < 8 else {
            log("Límite de intentos del prototipo alcanzado. Cierra y abre la app antes de continuar."); return
        }
        connecting = true
        wantsOutgoing = true
        attemptStarted = ProcessInfo.processInfo.systemUptime
        logLinkState("Antes de conectar")
        if selected.isConnected() {
            log("Enlace Bluetooth básico ya conectado. Se conserva la conexión compartida.")
            openOutgoing(psm: 0x11, device: selected)
            return
        }
        let session = generation
        let callback = ProbeBaseband()
        callback.completion = { [weak self] device, result in
            guard let self, self.active, self.generation == session else { return }
            if let device, device.addressString != self.selected?.addressString { return }
            self.log(String(format: "Finalización enlace básico: 0x%08X", result))
            self.logLinkState("Después del enlace básico")
            guard result == kIOReturnSuccess, let device, device.isConnected() else {
                self.fail("No se completó el enlace Bluetooth básico; aún no se intentó abrir HID."); return
            }
            guard self.controlChannel == nil else { return }
            self.openOutgoing(psm: 0x11, device: device)
        }
        basebandAttempts.append(callback)
        armConnectionTimeout(phase: "enlace Bluetooth básico", seconds: 12)
        // 0x3200 slots × 0.625 ms = 8 seconds; callback target makes this asynchronous.
        let result = selected.openConnection(callback, withPageTimeout: 0x3200, authenticationRequired: true)
        log(String(format: "Solicitud enlace básico autenticado: 0x%08X", result))
        if result != kIOReturnSuccess {
            callback.completion = nil
            if selected.isConnected() { openOutgoing(psm: 0x11, device: selected) }
            else { fail("Solicitud de enlace Bluetooth básico rechazada.") }
        }
    }

    func waitForIncoming() {
        guard active, canSelectDevice, selected?.isPaired() == true else { return }
        guard retired.count < 8 else { log("Reinicia la app antes de otro intento."); return }
        connecting = true
        attemptStarted = ProcessInfo.processInfo.systemUptime
        wantsOutgoing = false
        logLinkState("Espera entrante")
        log("En el Mac personal abre Ajustes > Bluetooth e intenta conectar al Mac del trabajo, si aparece esa opción.")
        log("Solo se aceptarán canales del receptor seleccionado. No se abrirán canales salientes automáticamente en esta espera.")
        armConnectionTimeout(phase: "conexión iniciada desde el Mac personal", seconds: 45)
    }

    private func logLinkState(_ label: String) {
        guard let selected else { return }
        log("\(label): emparejado=\(selected.isPaired()), enlace=\(selected.isConnected()), cifrado=\(selected.isConnected() ? String(selected.getEncryptionMode()) : "no disponible"), canales=\(opened.sorted().map { String(format: "0x%04X", $0) }.joined(separator: ",")).")
    }

    private func armConnectionTimeout(phase: String, seconds: TimeInterval = 12) {
        self.phase = phase
        connectionTimer?.invalidate()
        let session = generation
        log("Esperando \(phase) (máximo \(Int(seconds)) s).")
        connectionTimer = ProbeTimer.schedule(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.active, self.generation == session else { return }
                self.logLinkState("Estado al agotar el tiempo")
                self.log(String(format: "Tiempo total del intento: %.1f s", ProcessInfo.processInfo.systemUptime - self.attemptStarted))
                self.fail("Timeout esperando \(self.phase). Un PSM publicado localmente no garantiza que el receptor acepte HID.")
            }
        }
    }

    private func openOutgoing(psm: UInt16, device: IOBluetoothDevice) {
        armConnectionTimeout(phase: psm == 0x11 ? "canal HID de control 0x0011" : "canal HID de interrupción 0x0013")
        let writer = makeChannel(psm: psm)
        if psm == 0x11 { controlChannel = writer } else { interruptChannel = writer }
        var channel: IOBluetoothL2CAPChannel?
        let result = device.openL2CAPChannelAsync(&channel, withPSM: psm, delegate: writer)
        if writer.channel == nil { writer.channel = channel }
        log("La solicitud asíncrona \(channel == nil ? "no devolvió" : "devolvió") un objeto de canal; falta su callback.")
        log(String(format: "Apertura PSM 0x%04X: 0x%08X", psm, result))
        if result != kIOReturnSuccess { fail("La apertura L2CAP fue rechazada.") }
    }

    private func makeChannel(psm: UInt16) -> ProbeChannel {
        let session = generation
        let writer = ProbeChannel()
        writer.onError = { [weak self] message in guard let self, self.generation == session else { return }; self.fail(message) }
        writer.onClose = { [weak self] in guard let self, self.generation == session else { return }; self.fail("Canal HID desconectado. This Mac sigue activo.") }
        writer.onOpen = { [weak self] result in
            guard let self, self.active, self.generation == session else { return }
            self.log(String(format: "Callback L2CAP PSM 0x%04X: 0x%08X", psm, result))
            guard result == kIOReturnSuccess else {
                self.fail(String(format: "Finalización L2CAP: 0x%08X", result)); return
            }
            self.opened.insert(psm)
            if self.wantsOutgoing, psm == 0x11, self.interruptChannel == nil, let device = self.selected {
                self.openOutgoing(psm: 0x13, device: device)
            }
            self.checkReady()
        }
        writer.onData = { [weak self] bytes in guard let self, self.generation == session else { return }; self.receive(bytes, control: psm == 0x11) }
        return writer
    }

    private func checkReady() {
        guard opened == [0x11,0x13], !ready else { return }
        guard let selected, selected.isPaired(), selected.isConnected() else {
            fail("No se confirmó vínculo emparejado y conectado. No se enviará entrada."); return
        }
        guard selected.getEncryptionMode() != 0 else {
            guard encryptionTimer == nil else { return }
            armConnectionTimeout(phase: "confirmación de cifrado", seconds: 5)
            let session = generation
            encryptionTimer = ProbeTimer.schedule(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.active, self.generation == session else { return }
                    self.checkReady()
                }
            }
            return
        }
        connectionTimer?.invalidate()
        encryptionTimer?.invalidate()
        connecting = false
        ready = true
        log("CANALES LISTOS · receptor emparejado y cifrado. Falta verificar entrada en el otro Mac.")
        sendReport(HIDReports.keyboardNeutral)
        sendReport(HIDReports.mouseNeutral)
        onChange?()
    }

    private func receive(_ bytes: [UInt8], control: Bool) {
        guard active else { return }
        if !control {
            if bytes.count == 3, bytes[0] == 0xA2, bytes[1] == 1 {
                log("Informe de indicadores LED recibido (sin contenido de teclas).")
            } else { fail("Mensaje inesperado en canal de interrupción.") }
            return
        }
        if let command = bytes.first, [0x11,0x12,0x13,0x15].contains(command) {
            fail("El receptor solicitó reset, suspensión o desconexión HID."); return
        }
        if let response = HIDReports.response(to: bytes, keyboard: currentKeyboard, mouse: currentMouse) { controlChannel?.send(response) }
    }

    private func sendReport(_ report: [UInt8]) {
        guard ready else { return }
        guard let selected, selected.isConnected(), selected.isPaired(), selected.getEncryptionMode() != 0 else {
            fail("El enlace dejó de estar disponible o cifrado."); return
        }
        if report.first == 1 { currentKeyboard = report } else { currentMouse = report }
        interruptChannel?.send(HIDReports.packet(report))
    }

    /// No arbitrary input: only explicit, fixed test actions with a 3-second countdown.
    func test(_ kind: Int) {
        guard ready, !testing, interruptChannel?.idle == true else { return }
        testing = true
        let session = generation
        log("Prueba en 3 segundos. Mantén el foco en una ventana de prueba del receptor.")
        testTimer = ProbeTimer.schedule(withTimeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.ready, self.generation == session else { return }
                self.sendReport(kind == 0 ? HIDReports.keyA : kind == 1 ? HIDReports.moveRight : HIDReports.leftDown)
                self.testTimer = ProbeTimer.schedule(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let self, self.ready, self.generation == session else { return }
                        self.sendReport(HIDReports.keyboardNeutral)
                        self.sendReport(HIDReports.mouseNeutral)
                        self.testing = false
                        self.log("Prueba encolada con liberaciones. Confirma el resultado visible en el receptor.")
                    }
                }
            }
        }
    }

    private func fail(_ message: String) { guard active else { return }; log("ERROR: " + message); stop() }

    var onChange: (() -> Void)?
    var report: String { lines.joined(separator: "\n") }

    func log(_ text: String) {
        lines.append(text)
        if lines.count > 100 { lines.removeFirst(lines.count - 100) }
        onChange?()
    }

    func start() {
        guard !active, record == nil else { return }
        lines = []
        log("InputSwitch 0.2.1 · SDP HID v1 · This Mac")
        log("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        log("Sin captura global. Solo pruebas explícitas. Identificadores del equipo omitidos.")
        guard let controller = IOBluetoothHostController.default() else {
            log("ERROR: controlador Bluetooth no disponible."); return
        }
        guard controller.powerState == kBluetoothHCIPowerStateON else {
            log("ERROR: Bluetooth apagado. Actívalo desde Ajustes del Sistema y reintenta."); return
        }
        guard let published = IOBluetoothSDPServiceRecord.publishedServiceRecord(with: HIDDescriptor.service) else {
            log("ERROR: publicación SDP rechazada (la API devuelve nil, sin IOReturn).")
            log("No prueba por sí solo un bloqueo corporativo. Revisa el permiso Bluetooth y cierra otras apps HID.")
            return
        }
        record = published
        var control: BluetoothL2CAPPSM = 0
        let result = published.getL2CAPPSM(&control)
        let interrupt = HIDDescriptor.interruptPSM(published)
        log(String(format: "Lectura SDP: IOReturn 0x%08X; control 0x%04X", result, control))
        log(interrupt.map { String(format: "Interrupción asignada: 0x%04X", $0) } ?? "ERROR: no se pudo leer el PSM de interrupción.")
        guard result == kIOReturnSuccess, control == 0x11, interrupt == 0x13 else {
            log("BLOQUEO: los PSM publicados no coinciden con HID (0x0011 y 0x0013).")
            log("Se retira el servicio. No se intentará usar canales reasignados como si fueran HID.")
            stop(); return
        }
        // Incoming channels are restricted to the explicitly selected paired device.
        for psm: BluetoothL2CAPPSM in [0x11, 0x13] {
            guard let notification = IOBluetoothL2CAPChannel.register(forChannelOpenNotifications: self,
                selector: #selector(channelOpened(_:channel:)), withPSM: psm,
                direction: kIOBluetoothUserNotificationChannelDirectionIncoming) else {
                log("ERROR: registro de notificación L2CAP rechazado."); stop(); return
            }
            notifications.append(notification)
        }
        active = true
        log("PUBLICACIÓN CORRECTA. Servicio temporal activo; no demuestra entrada HID funcional.")
        log("Selecciona el receptor emparejado y pulsa Conectar HID.")
        log("Detén la prueba antes de cerrar o cambiar de equipo.")
    }

    @objc private func channelOpened(_ notification: IOBluetoothUserNotification, channel: IOBluetoothL2CAPChannel) {
        guard active, let selected, selected.isPaired(),
              channel.device?.addressString == selected.addressString else {
            _ = channel.close(); log("Canal entrante rechazado: par no seleccionado o no emparejado."); return
        }
        let psm = channel.psm
        guard (psm == 0x11 && controlChannel == nil) || (psm == 0x13 && interruptChannel == nil) else {
            _ = channel.close(); return
        }
        guard retired.count < 8 else { _ = channel.close(); return }
        let writer = makeChannel(psm: psm)
        writer.channel = channel
        let result = channel.setDelegate(writer)
        guard result == kIOReturnSuccess else { _ = channel.close(); fail("No se pudo recibir el canal entrante."); return }
        if psm == 0x11 { controlChannel = writer } else { interruptChannel = writer }
        connecting = true
        opened.insert(psm)
        log(String(format: "Canal entrante aceptado: 0x%04X", psm))
        armConnectionTimeout(phase: "segundo canal HID entrante")
        checkReady()
    }

    func stop() {
        generation += 1
        connecting = false
        wantsOutgoing = false
        encryptionTimer?.invalidate()
        encryptionTimer = nil
        basebandAttempts.forEach { $0.completion = nil }
        let wasReady = ready
        ready = false
        testing = false
        connectionTimer?.invalidate()
        testTimer?.invalidate()
        opened.removeAll()
        currentKeyboard = HIDReports.keyboardNeutral
        currentMouse = HIDReports.mouseNeutral
        active = false
        for writer in [controlChannel, interruptChannel].compactMap({ $0 }) {
            if wasReady && writer === interruptChannel { writer.finishWithNeutral() }
            else { writer.close() }
            // Retain delegates for late open/write callbacks; bounded to four attempts per run.
            retired.append(writer)
        }
        controlChannel = nil
        interruptChannel = nil
        notifications.forEach { $0.unregister() }
        notifications.removeAll()
        if let record {
            let result = record.remove()
            log(String(format: "Retirada SDP: 0x%08X", result))
            if result == kIOReturnSuccess { self.record = nil }
            else { log("No se confirmó la retirada. Cierra la app antes de reintentar.") }
        }
        onChange?()
    }
}
