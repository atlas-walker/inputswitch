# Plan de implementación: InputSwitch para macOS

**Fecha:** 24 de septiembre de 2026.  
**Estado:** hito 1 implementado; build de ejecución con firma ad hoc. Validación en el Mac del trabajo pendiente; Bluetooth y captura sin implementar. Véase `README.md`.  
**Nombre provisional:** InputSwitch.  
**Equipo emisor:** MacBook Pro M4 del trabajo, macOS Tahoe **26.7**, versión indicada por el usuario.  
**Equipo receptor:** Mac personal de Andrés; modelo, arquitectura y versión de macOS pendientes de confirmar.

## 1. Resultado que queremos

Dejar el Mac del trabajo delante y utilizar su teclado integrado y su trackpad para manejar alternativamente ese Mac o el Mac personal. Cada equipo conserva su propia pantalla y aplicaciones.

En la barra de menús del Mac del trabajo habrá un icono con un menú sencillo:

```text
InputSwitch · This Mac

✓ This Mac
  Andrés PC                 Conectado
────────────────────────────────────
  Configurar dispositivo…
  Ajustes…
  Salir
```

Seleccionar **Andrés PC** dirige la entrada al personal por Bluetooth. Seleccionar **This Mac** devuelve el control local. El nombre mostrado es un alias configurable, no un hostname que deba resolverse por red.

### Requisitos obligatorios

- Sin pagos de licencia ni suscripción para utilizar nuestra app.
- Sin App Store, `sudo`, cuenta de administrador, instalador de sistema ni herramientas de desarrollo en el Mac del trabajo.
- Aplicación ejecutada dentro de la sesión del usuario del trabajo.
- Transporte Bluetooth; sin Wi-Fi, TCP/IP, nube, VPN adicional ni puertos de red.
- Teclado y funciones habituales de ratón desde el trackpad.
- Cambio de destino claro, sin enviar la misma pulsación a ambos equipos.
- Recuperación local rápida si la conexión falla.
- Desarrollo posterior: esta entrega contiene únicamente el plan.

### Alcance inicial

Un emisor y un receptor configurado. Preferencia por presentarse ante el personal como un teclado y ratón Bluetooth estándar, sin instalar nada allí. El control inverso —personal hacia trabajo— no forma parte de esta primera entrega.

El usuario indica que KeyPad funciona en su configuración. Esto es evidencia favorable para Bluetooth entre sus equipos, pero todavía no confirma qué permisos utilizó, si funcionaron todos los atajos y el trackpad, ni cómo implementa esa app el enlace.

## 2. Decisión técnica y límites que deben quedar claros

**Propuesta principal: aplicación nativa en Swift + AppKit, compilada en el Mac personal y entregada como una única `.app` arm64 al Mac del trabajo.** No se necesita un intérprete instalado en el trabajo.

Hay tres verificaciones independientes antes de desarrollar el producto completo:

1. **Ejecución:** el equipo del trabajo permite abrir nuestro binario con su firma y forma de distribución reales.
2. **Entrada:** el usuario puede autorizar la captura que requiere el modo completo, o acepta las limitaciones del modo en primer plano.
3. **Bluetooth:** nuestra implementación puede transmitir teclado y ratón entre estos dos Mac, en particular desde Tahoe 26.7.

**No podemos prometer simultáneamente una app invisible con captura global, cero autorizaciones y funcionamiento en cualquier Mac administrado.** Ejecutarse sin privilegios y obtener permisos de privacidad son asuntos diferentes. Si una política bloquea la ejecución o Accesibilidad, cambiar a Python, Java o un servicio de usuario no elimina esa condición.

La documentación de Apple distingue entre observar entrada y modificar su recorrido. Para impedir que las teclas lleguen también a la aplicación local, el modo completo necesita un tap activo y comprobar Accesibilidad. La documentación reciente de KeyPad también exige Accesibilidad para reenviar atajos como ⌘Tab y ⌘Espacio; su descripción general de «solo Bluetooth» no cubre ese modo. Fuentes: [Apple, Advances in macOS Security](https://developer.apple.com/videos/play/wwdc2019/701/) y [KeyPad, Power user features, actualización de abril de 2026](https://bluetooth-keyboard.com/power-user/).

## 3. Lenguaje, componentes y herramientas

| Elemento | Elección propuesta | Motivo |
|---|---|---|
| Lenguaje | Swift, toolchain estable de Swift 6 incluido en el Xcode elegido | Acceso directo a APIs de macOS; binario nativo; sin runtime externo que instalar en el trabajo. |
| Interfaz | AppKit: `NSStatusItem`, `NSMenu`, una ventana pequeña de ajustes | Encaja con un menú nativo y evita una interfaz pesada. |
| Captura global | CoreGraphics / Quartz Event Services | Capturar y consumir teclado, botones, movimiento y scroll. |
| Captura de primer plano | AppKit `NSWindow` / `NSView` y eventos locales | Alternativa cuando no se pueda conceder captura global. |
| Permisos | ApplicationServices y autorización Bluetooth | Comprobaciones explícitas, antes de capturar. |
| Bluetooth HID principal | IOBluetooth, SDP y L2CAP | Candidato para emular teclado y ratón mediante Bluetooth Classic. Debe superar la prueba física. |
| Transporte alternativo | CoreBluetooth con servicio GATT propio | Solo si HID directo falla; necesita una app receptora en el personal. |
| Preferencias | `UserDefaults` | Alias, identificador de destino, sensibilidad y atajo. |
| Secretos, si hay protocolo propio | Keychain + CryptoKit | Identidad del par y autenticación de sesiones. |
| Inicio al entrar a la sesión | `SMAppService.mainApp`, opcional | Arranque de la app del usuario, sin daemon de sistema. |
| Pruebas | XCTest, dobles del transporte y validación con los dos Mac | Verificar protocolo y recuperación sin depender siempre del radio. |
| Dependencias externas | Ninguna en la primera implementación | Menos empaquetado, licencias y puntos de fallo. |

La app utilizará `LSUIElement = true` para aparecer como aplicación de barra de menús sin icono permanente en el Dock. Apple documenta el menú de `NSStatusItem` y ese comportamiento de `LSUIElement`: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem), [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement).

### Compilación y compatibilidad

- Compilar en el personal con Xcode y el SDK de macOS adecuado. Fijar la versión de Xcode/Swift utilizada en el proyecto; no dejar «la última versión» como dependencia indefinida.
- Emisor inicial: arquitectura `arm64`, deployment target propuesto macOS 26.0, validación real obligatoria en **26.7**. Ajustar solo si el SDK o las APIs seleccionadas lo requieren.
- El Mac personal no necesita Xcode para recibir HID. Si se elige la alternativa con receptor, confirmar primero su versión y si es Intel o Apple Silicon; compilar el receptor para ese equipo.
- Preferir APIs públicas. Un pequeño puente Objective-C sería aceptable si una firma de IOBluetooth se importa mal a Swift; no justifica reescribir toda la aplicación.
- Mantener proyecto Xcode y un paquete Swift local para las partes puras de protocolo/estado. Construir mediante Xcode o `xcodebuild` en el personal.

### Código de referencia y licencia propia

Implementar desde especificaciones y APIs públicas; no copiar binarios ni código de KeyPad. Los repositorios estudiados se usarán con procedencia y licencia registradas. `darwin-bt-remote` declara AGPL-3.0-only; cualquier reutilización debe respetar esa licencia, no incorporarse silenciosamente a una app con otra licencia. Preferencia inicial: implementación independiente, sin dependencias externas, y decidir una licencia libre para nuestro código antes de publicarlo. Referencia: [licencia del proyecto darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote/blob/main/LICENSE).

### Por qué no elegir Python, Java o un servicio como base

Python exigiría resolver intérprete, PyObjC, empaquetado y firma. Java necesitaría JVM y puentes nativos para captura y Bluetooth. Ambos conservan los mismos controles de macOS. Una `.app` nativa copiable es más sencilla de ejecutar para este caso.

Un LaunchAgent no aporta una ventaja necesaria: necesitamos una interfaz en la sesión gráfica, no un proceso de sistema. El arranque automático se añadirá después, mediante la propia app. Apple proporciona [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) para registrarla como elemento de inicio.

## 4. Distribución sin App Store y sin administrador

### Entrega prevista

Un archivo ZIP con `InputSwitch.app`, instrucciones breves, versión y suma SHA-256. Se copia mediante un medio que el equipo permita a `~/Applications/InputSwitch.app`, dentro de la carpeta del usuario. No utilizar `/Applications` como requisito, ni distribuir un `.pkg` que solicite elevación.

El ejecutable, sus recursos y cualquier biblioteca necesaria deben ir empaquetados. En el trabajo no se instalarán Xcode, Homebrew, Python, Java, Rosetta, drivers ni extensiones.

### Firma: condición que puede bloquear el coste cero

- Para desarrollo propio, generar una firma local/ad hoc compatible con la ejecución en Apple Silicon. **Esa firma no equivale a Developer ID ni a notarización y no garantiza que Gatekeeper permita abrir la app transferida.**
- La ruta convencional para distribuir fuera de la tienda es Developer ID y notarización. Necesita acceso a una membresía/certificado de desarrollador; no suponer que es gratis ni que el usuario lo tiene.
- Si existe ya una identidad de firma disponible de forma autorizada, se puede evaluar usarla sin comprar una nueva. No es un requisito que podamos dar por satisfecho.
- Si el equipo bloquea la app y la única excepción requiere un administrador, la distribución gratuita autónoma queda bloqueada. No incluir como «solución» quitar cuarentena, desactivar Gatekeeper, editar TCC/MDM ni firmar simulando otra aplicación.
- Solo considerar compilación local como alternativa si las herramientas ya están presentes y su uso está permitido; no asumir que instalar el compilador evitaría las restricciones.

Apple describe las modalidades de exportación y la ruta Developer ID en [distribución de aplicaciones](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases) y [firma para Gatekeeper](https://developer.apple.com/developer-id/).

**Primera prueba futura:** distribuir un esqueleto mínimo con el bundle ID y la ruta previstos. Si no se abre con el usuario del trabajo, resolver ese resultado antes de desarrollar Bluetooth. Tener permiso de usar KeyPad no implica que un binario propio herede su confianza.

Mantener bundle ID, ruta e identidad de firma lo más estables posible. Verificar las autorizaciones después de cada actualización: una build nueva, especialmente con firma ad hoc, puede provocar nuevas solicitudes.

## 5. Permisos y dos modos de captura

| Capacidad | Dónde | Requisito y comprobación |
|---|---|---|
| Usar Bluetooth | Trabajo; también personal si hay receptor propio | Declaración de propósito en `Info.plist`, autorización de la app y radio disponible. Emparejar un teclado físico no demuestra que una app tenga permiso Bluetooth. |
| Capturar y suprimir globalmente | Trabajo, modo completo | Comprobar Accesibilidad y crear realmente un tap activo. No basta con ver un interruptor en Ajustes. |
| Observar entrada con APIs pasivas, si llegasen a usarse | Trabajo | Evaluar Monitorización de entrada; no pedirla por rutina si no se usa. |
| Eventos de la ventana propia | Trabajo, modo de primer plano | App activa y con foco; no observa otras aplicaciones. |
| Inyectar entrada desde receptor propio | Solo personal, alternativa GATT | Accesibilidad y acceso a publicación de eventos, comprobados en el personal. |
| Inicio automático | Trabajo, opcional | Registro como elemento de inicio y ausencia de bloqueo corporativo. No imprescindible. |

En el esquema PPPC de Apple, la autorización para que un usuario estándar configure ciertos servicios solo se aplica a servicios concretos; no hay una garantía general para Accesibilidad. Si se exigen credenciales de administrador que el usuario no tiene, se registra el bloqueo y se evalúa el modo de primer plano. Fuentes: [PPPC de Apple](https://developer.apple.com/documentation/devicemanagement/privacypreferencespolicycontrol/services-data.dictionary/identity), [autorizar Accesibilidad](https://support.apple.com/es-lamr/guide/mac-help/mh43185/26/mac/26).

### Modo A: experiencia completa de barra de menús

- Captura mediante `CGEvent.tapCreate`, ubicación `.cgSessionEventTap`, inserción `.headInsertEventTap`, opción `.defaultTap`.
- Comprobar `AXIsProcessTrustedWithOptions` y el resultado de crear el tap. Si devuelve `nil`, no activar control remoto.
- En local, la entrada funciona normalmente. En remoto, consumir los eventos reenviados para que no actúen en la app del trabajo.
- El callback clasifica y encola; no realiza I/O Bluetooth, escribe archivos ni espera a la interfaz.
- Probar por separado la mecánica del cursor: consumir `mouseMoved` no demuestra por sí solo movimiento relativo continuo. Verificar deltas más allá de todos los bordes, posición local y comportamiento con varias pantallas en Tahoe 26.7. Cualquier estrategia de asociación o recentrado debe funcionar con los permisos permitidos y restaurarse al salir.
- No usar `.listenOnly` como sustituto: observa pero no impide el efecto local.
- No basar el diseño en `.cghidEventTap` ni acceso exclusivo al hardware: la documentación de Apple contiene una exigencia de root para ese punto de captura.
- No activar App Sandbox en la primera build de desarrollo fuera de la tienda. Evaluar entitlements y hardened runtime según las APIs y la firma elegidas; ninguno sustituye el consentimiento de privacidad.

Fuentes: [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)), [callback de eventos](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback), [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).

### Modo B: alternativa si Accesibilidad está bloqueada

Seleccionar Andrés PC abre y enfoca una ventana de captura sencilla. Los eventos que recibe esa ventana se transmiten al personal. Al perder el foco, vuelve automáticamente a This Mac.

- Capturar `keyDown`, `keyUp`, `flagsChanged`, clics, movimiento, arrastre y scroll desde AppKit.
- Usar un receptor de eventos que no se comporte como un campo de texto con edición o menús propios.
- Atajos del sistema, por ejemplo ⌘Tab/⌘Espacio, pueden seguir actuando localmente. No prometer que se pueden redirigir todos sin Accesibilidad.
- Probar `CGAssociateMouseAndMouseCursorPosition(false)` en primer plano para recibir movimiento relativo sin chocar con los bordes. Comprobar su retorno y requisitos en 26.7; si no funciona, documentar la superficie de captura limitada.
- Restaurar siempre la asociación del cursor al perder foco, cancelar, cerrar o fallar.
- Al abrir cualquier menú local, detener el envío, liberar estado remoto y restaurar el cursor antes de entrar en el seguimiento del menú. Los monitores locales no reciben necesariamente eventos de esos bucles; ningún clic destinado al menú debe llegar al personal.

Apple documenta los [monitores locales de eventos](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)) y la [asociación entre movimiento y cursor](https://developer.apple.com/documentation/coregraphics/cgassociatemouseandmousecursorposition(_:)).

**Este modo es una alternativa con limitaciones, no una implementación equivalente al dropdown global solicitado.** Si el modo A queda bloqueado, presentar el resultado de la prueba y estas diferencias antes de dedicar tiempo a pulir el modo B.

## 6. Bluetooth: arquitectura principal y prueba de viabilidad

```text
MAC DEL TRABAJO — emisor                       MAC PERSONAL — receptor

Teclado + trackpad
        │
Captura de entrada
        │
Selección de destino + estado de teclas
        │
Codificador HID
        │
IOBluetooth / Bluetooth Classic ─────────────► Driver HID de macOS
                                               │
                                               Aplicación activa del personal
```

No hay captura de imagen, transmisión de pantalla, lectura de portapapeles ni conexión a Internet. La VPN no participa en el transporte, aunque una política del equipo puede restringir las aplicaciones o el propio Bluetooth.

### Por qué IOBluetooth es un candidato y no una garantía

Apple proporciona acceso Bluetooth en espacio de usuario y APIs para publicar servicios SDP. Eso permite investigar esta vía sin programar un driver. Publicar un servicio, sin embargo, no demuestra que macOS permita operar correctamente como teclado HID en cualquier versión. Fuentes: [IOBluetooth](https://developer.apple.com/documentation/iobluetooth), [publicación de un registro SDP](https://developer.apple.com/documentation/iobluetooth/iobluetoothsdpservicerecord/publishedservicerecord(with:)).

Existen implementaciones públicas, pero no constituyen una prueba en Tahoe 26.7. El proyecto [Bluetooth-Keyboard-Emulator](https://github.com/ArthurYidi/Bluetooth-Keyboard-Emulator) está archivado y documenta problemas históricos. El repositorio [darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote) anuncia soporte amplio, pero su código y notas contienen restricciones de rol y conexión. Se estudiarán como referencias, sin copiar sus afirmaciones de compatibilidad.

### Prueba mínima antes de desarrollar el producto

1. Cerrar KeyPad y otras apps que puedan publicar servicios HID; evitar competencia y registros antiguos.
2. Publicar un registro SDP HID **temporal**, no persistente, con descriptor estable de teclado y ratón.
3. Usar Service Class HID `0x1124` y evaluar los canales L2CAP de control `0x11` e interrupción `0x13`.
4. Leer el registro realmente publicado. Apple puede reasignar PSM ocupados: comprobar qué se obtuvo y si el receptor lo acepta, sin tratar una devolución positiva como éxito funcional.
5. Evaluar los caminos públicos de conexión saliente y notificación/aceptación entrante. Registrar cuál es posible; no asumir que `bluetoothd` cederá los canales HID.
6. Emparejar mediante mecanismos y diálogos del sistema. Verificar autenticación/cifrado y que el receptor sea el Mac seleccionado.
7. Con una ventana de prueba y acción explícita del usuario, enviar una tecla y su liberación, un movimiento y un clic con su liberación.
8. Comprobar en el personal que existe entrada real de teclado/ratón. La aparición en una lista Bluetooth no es suficiente.
9. Desconectar y reconectar; repetir tras cerrar la app y tras suspensión.

**Éxito:** teclado y ratón funcionales entre estos dos Mac, sin permisos de administrador, APIs privadas ni procesos de sistema modificados. Si falla, conservar códigos de error y resultados de cada canal antes de decidir el siguiente transporte.

### CoreBluetooth BLE HID: no asumir que es intercambiable

CoreBluetooth permite servicios GATT, pero no se debe afirmar que publicar el servicio HID estándar `0x1812` esté permitido en estas condiciones. Existe un error público `uuidNotAllowed`. Cambiar un UUID SIG de 16 bits a su representación completa no crea un servicio distinto: Apple documenta su equivalencia. Fuentes: [CBUUID](https://developer.apple.com/documentation/corebluetooth/cbuuid), [uuidNotAllowed](https://developer.apple.com/documentation/corebluetooth/cberror-swift.struct/code/uuidnotallowed).

Un experimento BLE HID con APIs públicas puede evaluarse si aporta información, pero no será la base de un compromiso de entrega ni se utilizarán trucos con APIs privadas para forzarlo.

## 7. Informes HID, teclado y trackpad

### Descriptor y protocolo

- Descriptor compuesto estable: teclado y ratón, con Report IDs distintos; control multimedia opcional después.
- Teclado inicial de seis teclas simultáneas más modificadores; declarar el límite y gestionar overflow de manera explícita. NKRO queda para una versión posterior si se necesita.
- Informes de ratón con botones, deltas relativos X/Y, rueda vertical y desplazamiento horizontal, siempre que el descriptor elegido lo soporte y el Mac lo interprete correctamente.
- Mantener coherencia entre descriptor SDP, tamaños, IDs y bytes enviados por HIDP. Especificar en la implementación qué capa añade el encabezado del mensaje.
- Procesar los mensajes de control HID necesarios: negociación de protocolo, peticiones de informes/estado, suspensión, salida de suspensión y desconexión. Responder de acuerdo con el perfil; no ignorar solicitudes silenciosamente.
- Si se anuncia compatibilidad boot, implementarla y probarla; si no, no anunciarla. Report protocol es el objetivo inicial.
- Gestionar informes de salida del teclado, incluidos indicadores cuando corresponda; evitar inventar el estado de Caps Lock del receptor.
- Descriptor versionado: si cambia, prever que macOS conserve información de la vinculación anterior. Documentar cuándo hará falta olvidar y volver a emparejar.
- En L2CAP, comprobar MTU saliente y estado de cada canal, usar envío asíncrono y conservar el buffer hasta la finalización requerida por la API. Tratar cada error/cierre y limitar escrituras pendientes. Referencia: [IOBluetoothL2CAPChannel.writeAsync](https://developer.apple.com/documentation/iobluetooth/iobluetoothl2capchannel/writeasync(_:length:refcon:)).

La implementación seguirá el perfil [Bluetooth HID 1.1.1](https://www.bluetooth.com/specifications/specs/hid-1-1-1/) y las [HID Usage Tables 1.7 de USB-IF](https://www.usb.org/document-library/hid-usage-tables-17). Se fijarán las revisiones efectivamente consultadas al programar.

### Teclado

- Traducir códigos físicos de macOS a usages HID; no enviar cadenas de texto como sustituto del teclado.
- Mantener pulsación/liberación y modificadores izquierdo/derecho: Shift, Control, Option y Command.
- El layout del receptor determina los caracteres. Confirmar ANSI/ISO y distribución española, latinoamericana o estadounidense de ambos Mac.
- Probar `ñ`, tildes, teclas muertas, símbolos de programación, combinaciones con Option y teclas de navegación.
- En HID directo, enviar el estado de tecla mantenida y dejar la repetición al receptor; no duplicar repeticiones de AppKit sobre la repetición que ya genera el sistema remoto.
- No prometer reenviar Touch ID, el botón físico de encendido ni todas las funciones especiales de `Fn`/Globe. Las teclas multimedia requieren sus usages y pruebas propias.
- `CGEventTap` representa entrada de la sesión: el MVP también puede capturar teclado o ratón externos conectados al emisor. Filtrar exclusivamente el hardware integrado no es un requisito garantizado.

### Trackpad: compromiso funcional

La primera versión debe permitir movimiento, clic principal, clic secundario, doble clic, selección, arrastrar/soltar y scroll vertical/horizontal. Aprovechar los clics y gestos que macOS ya traduzca a eventos de ratón.

**Esto no equivale a emular un Magic Trackpad.** Zoom con pinza, rotación, Force Touch, contactos multitáctiles crudos, Mission Control y cambios de escritorio con tres/cuatro dedos quedan fuera de la compatibilidad garantizada inicial. Se podrán estudiar traducciones a atajos, identificándolas como tales. Apple distingue estos eventos en [Handling Trackpad Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html).

Tratar explícitamente aceleración del cursor, escala, signo del scroll natural, scroll de alta resolución y momentum. Evitar aceleración doble y sumar solo deltas compatibles; no mezclar clics o liberaciones con paquetes de movimiento. Exponer como máximo sensibilidad y dirección de scroll en los ajustes iniciales.

## 8. Cambio de destino y acceso al menú mientras se controla el personal

Existe un detalle funcional: si todo el movimiento del trackpad va al personal, no se puede desplazar libremente el puntero por la barra de menús del trabajo al mismo tiempo.

**Solución propuesta para la primera versión:** el dropdown selecciona el destino y un atajo reservado permite volver al trabajo y abrir ese mismo menú. Valor inicial propuesto: **Control + Option + Escape**, configurable y sujeto a comprobar conflictos.

- Desde local: clic en icono → Andrés PC.
- Desde remoto: atajo de regreso → This Mac, restauración del cursor y apertura del menú → elegir destino si se desea.
- Reservar el atajo localmente antes de transmitirlo. Como algunos modificadores podrían haberse enviado ya, liberar el estado remoto al detectar el atajo completo.
- Mostrar la combinación de regreso en el menú y en el primer uso. No elegir ⌘OptionEscape, que coincide con Forzar salida.
- Una ruta de ratón exclusivamente hacia la barra local requeriría un modo adicional de acceso al menú; no ocultar esa complejidad ni prometerla sin prototipo.

### Secuencia de activación

1. El usuario selecciona Andrés PC.
2. La aplicación verifica permisos y transporte; mientras conecta, la entrada sigue siendo local.
3. Al cerrar el menú, espera a que se liberen teclas y botones usados para seleccionarlo.
4. Envía un estado remoto neutral y activa captura.
5. El icono y el menú pasan a indicar Andrés PC solo cuando el destino está listo.

### Secuencia de regreso

1. Deshabilitar nuevos envíos y devolver localmente la entrada general. Mantener únicamente un filtro transitorio para las teclas/botones ya retenidos y los del atajo de regreso.
2. Vaciar movimientos pendientes y liberar teclas/botones remotos si el enlace aún existe.
3. Resolver teclas físicamente mantenidas: consumir sus liberaciones finales cuando corresponda y retirar el filtro al soltarlas. Así se evita enviar `keyUp` a un equipo que no recibió `keyDown`, dejar un modificador retenido o permitir que el atajo parcial actúe localmente. El resto de la entrada ya funciona en el trabajo.
4. Restaurar asociación, posición y visibilidad del cursor.
5. Marcar This Mac. Si hubo error, mostrar una explicación corta.

No hacer la liberación depender de una espera Bluetooth indefinida: recuperar el control local tiene prioridad.

## 9. Modelo de estado y organización interna

```text
LOCAL → CONNECTING → REMOTE → RELEASING → LOCAL
          │            │
          └─ error ────┴───────────────→ LOCAL con diagnóstico
```

Permisos, disponibilidad del radio y conexión se modelan por separado; estar conectado no significa estar capturando. Tras arrancar, actualizar, desbloquear o reconectar, el destino activo será siempre This Mac hasta una selección explícita.

### Módulos previstos

```text
InputSwitch/
  App/                 Inicio, NSStatusItem, menú y ajustes
  Capture/             EventTapCapture y ForegroundCapture
  Routing/             InputRouter y máquina de estados
  HID/                 Descriptor, mapa de teclas e informes
  Transport/           Interfaz común y ClassicHIDTransport
  Permissions/         Comprobaciones y estados de autorización
  Recovery/            Liberación, timeouts y restauración de cursor
  Diagnostics/         Errores técnicos sin contenido escrito
  Resources/           Info.plist, icono y descriptor SDP
  Tests/               Estado, mapeos, protocolo y fallos simulados
```

Eventos internos: tecla abajo/arriba, modificadores, delta de puntero, botón abajo/arriba, scroll y release-all. Incluir identificador de sesión y marcas temporales internas para descartar entrada vieja. Separar este modelo del formato HID permite cambiar el transporte sin rehacer la interfaz.

Un coordinador decide el destino. El callback de captura consulta una instantánea pequeña y consistente; una cola serie gestiona el transporte; la interfaz se actualiza en el hilo principal. No ejecutar trabajo Bluetooth bloqueante en el callback ni acceder a AppKit desde callbacks de fondo.

## 10. Recuperación, latencia y comportamiento ante fallos

- Cola acotada: prioridad para liberaciones, botones y teclas; agrupar movimiento contiguo preservando orden alrededor de los clics. No reproducir una cola vieja tras reconectar.
- Si no se puede mantener una secuencia fiable de teclado, abandonar remoto y recuperar local en vez de continuar perdiendo eventos.
- Tratar `tapDisabledByTimeout` y `tapDisabledByUserInput`: dejar de suprimir entrada, limpiar estado, informar. No reactivar repetidamente en bucle.
- Desconexión, suspensión, cierre de tapa, bloqueo de sesión, cambio de usuario, revocación de permiso o cierre de la app: cancelar captura y restaurar control local. Detectar los eventos por APIs públicas; probar cada caso en el equipo real.
- La app no mantendrá despierto indefinidamente al Mac ni deshabilitará el bloqueo automático para sostener el enlace.
- Tras desconexión física no siempre se puede entregar el informe de liberación. Validar que el receptor limpia el estado al perder el dispositivo y enviar neutral al reconectar. No prometer liberación instantánea cuando el radio ya desapareció.
- Al cerrar de forma normal, restaurar todos los recursos. Probar también crash y terminación forzada: no dependen de que se ejecute el código de limpieza.
- Confirmar que el sistema devuelve control local si el proceso muere; no añadir un servicio privilegiado como mecanismo de recuperación.
- Entrada segura/Secure Input, pantallas de autorización y bloqueos pueden limitar la captura. No forzarlos; detectar lo posible y pasar a local con una explicación.

### Objetivos medibles, sujetos a la prueba física

- Cambio con enlace ya conectado: objetivo inferior a 500 ms; primera vinculación no entra en esta cifra.
- En condiciones normales de escritorio: objetivo de latencia perceptible de entrada por debajo de 50 ms; medir con una prueba reproducible y distinguir latencia total de tiempo de encolado.
- Movimiento inicial a un máximo propuesto de 125 Hz, ajustable según capacidad real del enlace; no retrasar teclas y clics detrás de una acumulación de movimiento.
- Sin sondeo intensivo cuando está en This Mac, sin teclado registrado en disco y sin crecimiento continuo de memoria durante una sesión larga.
- Recuperación ante error de transporte: inmediata desde la detección; añadir objetivos de detección y reconexión solo después de medir las APIs.

## 11. Alternativa por Bluetooth si HID directo no supera la prueba

Mantener la misma interfaz en el trabajo, pero transmitir eventos mediante un servicio Bluetooth LE propio a **InputSwitch Receiver**, instalado solamente en el personal.

```text
Trabajo: captura + menú
          │
          └── Bluetooth LE, servicio GATT propio ──► Personal: receptor + CGEvent
```

Esta ruta sigue sin utilizar red IP ni compartir pantallas. **El personal ya no lo verá como un teclado Bluetooth estándar:** una aplicación receptora traduce los eventos en entrada. Es una alternativa técnica que se presentará con esa diferencia; no sustituir la arquitectura principal silenciosamente.

### Diseño mínimo de esta alternativa

- Trabajo como central y personal como periférico GATT anunciante, usando UUID propios de 128 bits. Validar esos roles en los dos equipos antes de consolidarlos.
- Características separadas para establecimiento de sesión, entrada y estado/confirmaciones.
- Protocolo binario versionado, con tipos, límites de tamaño, contador, sesión y fragmentación cuando el MTU negociado lo exija.
- Teclas/botones/liberaciones ordenados y confirmados; movimiento agrupable. Usar backpressure de CoreBluetooth, no colas infinitas.
- Estado completo periódico de teclas/botones y un heartbeat durante remoto. Receptor libera la entrada al caducar la sesión; valor inicial a evaluar: 1 segundo, ajustable tras pruebas.
- Validar longitudes, versión y tipos antes de inyectar. Descartar duplicados, sesiones previas y mensajes no autenticados.
- Emparejar la app explícitamente: intercambio de claves con CryptoKit, confirmación de una huella en ambos Mac y almacenamiento de identidad en Keychain. Utilizar primitivas estándar para derivación y cifrado autenticado; no inventar un cifrado propio.
- Cifrado Bluetooth donde las APIs lo ofrezcan, además de autenticación del protocolo. Nombre visible y proximidad no son autenticación suficiente.
- Receptor en sesión de usuario con Accesibilidad, `CGPreflightPostEventAccess`/petición correspondiente y `CGEvent` para teclado, puntero y scroll. Definir repetición de teclas explícita; no asumir que eventos sintéticos mantenidos repiten como un HID físico.
- El receptor no ofrece soporte garantizado en FileVault, antes del login, en Secure Input o en ventanas protegidas. Validar la sesión normal desbloqueada como alcance inicial.
- Evitar bucles: un único rol emisor activo en esta versión; si el proyecto evoluciona, etiquetar los eventos inyectados.

Apple muestra intercambio GATT entre dispositivos en [Transferring Data Between Bluetooth Low Energy Devices](https://developer.apple.com/documentation/corebluetooth/transferring-data-between-bluetooth-low-energy-devices). Ese ejemplo demuestra mecanismos de transporte; no demuestra las prestaciones completas propuestas aquí.

Si tampoco funciona un servicio GATT propio o la app del trabajo no puede ejecutarse, documentar el bloqueo. No cambiar a red, hardware adicional o servicios de pago sin replantear el alcance con el usuario.

## 12. Datos, emparejamiento y mantenimiento

- Primera configuración: localizar y confirmar el Mac personal, asignarle alias «Andrés PC» y guardar el identificador del dispositivo, no depender solo de su nombre.
- HID directo: delegar claves de vínculo al sistema Bluetooth. Alternativa GATT: guardar además identidad de la app en Keychain.
- Aceptar entrada únicamente para el par configurado. No cambiar automáticamente a otro equipo que se anuncie con el mismo nombre.
- No guardar pulsaciones, textos, capturas de pantalla ni contenido del portapapeles. Logs limitados a estados, tiempos, errores y métricas agregadas; ocultar identificadores de dispositivo en diagnósticos compartidos.
- Nada de telemetría, analítica, anuncios ni actualización automática en la primera versión.
- Preferencias mínimas versionadas: dispositivo/alias, modo de captura, atajo, sensibilidad, scroll e inicio automático. La vinculación y los secretos no se guardan en un JSON de diagnóstico. Registrar códigos `IOReturn`/`CGError` y pasos fallidos, sin afirmar que un error desconocido es necesariamente MDM.
- Actualización manual: pasar a This Mac, cerrar, reemplazar la app conservando identidad/ruta cuando sea posible, abrir y repetir una prueba corta. Conservar una versión anterior para revertir.
- Desinstalación: salir, desactivar inicio automático si se usó, borrar la app y opcionalmente sus preferencias/vinculación. Sin componentes en carpetas de sistema.

## 13. Pruebas y criterios de aceptación

### Automatizables

1. Mapeo de teclas y modificadores, tamaños de informes y límites del descriptor.
2. Pulsar/mantener/liberar, overflow de seis teclas y Caps Lock según protocolo elegido.
3. Máquina de estados: conectar no activa remoto antes de estar listo; errores siempre devuelven local.
4. Cambio durante modificadores o arrastre: neutralización y reconciliación sin duplicados.
5. Cola llena, reconexión, respuestas tardías y descarte de sesiones antiguas.
6. Agrupación de movimiento sin cambiar el orden relativo de clics y liberaciones.
7. Si hay GATT propio: parser, tamaños, fragmentación, autenticación, rechazo de repetición y timeout del receptor.

### Con los dos Mac reales

| Prueba | Criterio de aprobación |
|---|---|
| Arranque en el trabajo | La build distribuida abre con el usuario estándar, sin instalar runtimes ni pedir admin. |
| Permisos | Se conoce qué modo es posible; ninguna captura se activa sin permiso válido. |
| Sin red local | Funciona con la VPN del trabajo activa y sin necesitar acceso IP al personal. No modificar la VPN. |
| Vinculación | Personal correcto, primera conexión y siguientes conexiones repetibles. |
| This Mac | Teclado y trackpad funcionan localmente y no producen acciones en el personal. |
| Andrés PC | Escritura y clics llegan al personal; una ventana de prueba local no recibe copias. |
| Regreso | Atajo recupera trabajo y menú; no quedan modificadores o clics presionados. |
| Teclado real | `ñ`, acentos, signos de programación, flechas, selección, copiar/pegar mediante atajos y repetición funcionan según layout. No implica compartir portapapeles. |
| Atajos globales | ⌘Tab y ⌘Espacio se prueban por separado; si quedan locales, se documenta limitación del modo. |
| Trackpad | Movimiento continuo, clic secundario, doble clic, selección, arrastre y scroll en ambos ejes. |
| Fallos | Apagar Bluetooth del personal, salir de alcance y cerrar la app mientras se mantiene una tecla/botón; vuelve local sin quedarse bloqueado. |
| Sesión | Suspender/despertar, bloquear/desbloquear y reiniciar; nunca reanudar captura remota por sorpresa. |
| Interferencias | Convivencia con auriculares/ratón Bluetooth, sin desconectar dispositivos ajenos. |
| Uso sostenido | Una sesión inicial de al menos 60 minutos con cambios repetidos, sin entrada perdida observable ni crecimiento continuo de colas. |
| Distribución | Repetir arranque, permisos y conexión desde el ZIP final, no solo desde Xcode. |

No usar pruebas unitarias como evidencia de que un radio, un perfil HID o una política de empresa funciona. Esas condiciones requieren prueba física.

## 14. Hitos de implementación y orden de trabajo

| Hito | Trabajo | Resultado y puerta de salida |
|---|---|---|
| 0. Confirmación | Datos de ambos equipos, layout, qué funcionó en KeyPad y qué permisos hay | Ficha de entorno. No solicitar al usuario cambios innecesarios ahora. |
| 1. Ejecución | Esqueleto `.app`, firma y distribución reales, icono mínimo | Abre sin admin en trabajo. Si falla, detener desarrollo de funciones hasta resolver esa restricción. |
| 2. Bluetooth | Publicación HID, vínculo, tecla/clic de prueba y reconexión | Prueba directa superada o informe preciso que justifique evaluar GATT. |
| 3. Captura | Captura activa y supresión; regreso local desde el primer prototipo | Modo A comprobado o limitaciones concretas del modo B. No construir una captura sin salida de emergencia. |
| 4. Funciones | Mapa de teclado, ratón, scroll, estados y dropdown | Flujo This Mac / Andrés PC completo. |
| 5. Resistencia | Sleep, pérdida de enlace, colas, actualización y fallos | Criterios de recuperación satisfechos en las máquinas reales. |
| 6. Entrega | ZIP, instrucciones y resultados | Aplicación utilizable sin entorno de desarrollo en el trabajo. |

Hitos 2 y 3 son pruebas de viabilidad pequeñas. No pulir ajustes, iconos o autoinicio antes de que ambos estén resueltos.

Estimación orientativa, no compromiso: si ejecución, permisos y HID directo funcionan, aproximadamente **4–8 jornadas de desarrollo y validación** para una primera versión cuidada. Un receptor GATT añade protocolo, autenticación y pruebas; estimar de nuevo después del prototipo. Una restricción de MDM no tiene una estimación de resolución por programación.

## 15. Decisiones pendientes, sin bloquear esta entrega del plan

- Confirmar versión/modelo del personal y distribución física de ambos teclados.
- Registrar exactamente qué funcionó en KeyPad: letras, ⌘Tab/⌘Espacio, trackpad, scroll y cambio de destino. No se solicita comprar la app.
- Confirmar si el trabajo permite abrir una `.app` propia transferida y autorizar Accesibilidad con el usuario actual.
- Comprobar disponibilidad de Xcode/herramientas de compilación en el personal y opciones de firma sin coste nuevo.
- Si Accesibilidad no es posible, decidir si el modo en primer plano resulta suficientemente cómodo.
- Si HID directo no es viable con APIs públicas, decidir si se acepta instalar el receptor gratuito en el personal.

## 16. Decisión recomendada para comenzar cuando se programe

Construir **Swift + AppKit, una `.app` de usuario, Bluetooth directo como primera ruta y teclado/ratón estándar como alcance inicial**. Verificar primero que la build abre en el trabajo; después demostrar transporte y permisos en Tahoe 26.7.

El resultado deseado es el dropdown simple pedido. Las alternativas quedan explícitas para que un límite de permisos o Bluetooth no se descubra después de construir toda la interfaz. La siguiente fase comenzará con las pruebas mínimas de viabilidad. En esta entrega solo se creó el plan; no se instaló ni ejecutó una aplicación propia.
