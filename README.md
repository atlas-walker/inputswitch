# InputSwitch

Aplicación nativa de barra de menús para macOS. El **hito 1 (arranque en el Mac
 del trabajo) ya fue confirmado**. La versión 0.2.1 implementa el prototipo de
 Bluetooth Classic HID: publicación SDP, conexión con un Mac emparejado y pruebas
 explícitas de tecla, movimiento y clic. Todavía no captura entrada global.

[Descargar 0.2.1](https://github.com/atlas-walker/inputswitch/releases/tag/v0.2.1)
· [Prueba Bluetooth](docs/PRUEBA-BLUETOOTH.md)
· [Resultados y pendientes](docs/VALIDACION.md)

## Compilar

En el Mac de desarrollo:

```sh
bash scripts/test.sh
bash scripts/build.sh
open build/InputSwitch.app
```

Toolchain utilizado: Swift 6.1.2, SDK macOS 15.5, Command Line Tools sobre macOS
15.3.2 arm64. No se requiere Xcode completo para esta primera build. El mínimo
se fija en macOS 15.0 para poder verificarla en este equipo; no constituye una
validación de compatibilidad Bluetooth o captura en macOS 26.7.

El script crea una `.app` con bundle ID `com.andres.inputswitch`, firma ad hoc,
ZIP con instrucciones y suma SHA-256 en `dist/`. No usa dependencias externas,
instalación global ni permisos de administrador. Abre `Sources` y `Resources`
en el editor que prefieras; el proyecto Xcode y el paquete de protocolo se
incorporarán al desarrollar los siguientes hitos.

Consulta [las instrucciones de prueba](docs/PRUEBA-TRABAJO.md). Una compilación
correcta o una ejecución local no sustituye esa prueba de distribución.
