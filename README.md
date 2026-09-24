# InputSwitch

Aplicación nativa de barra de menús para macOS. La implementación actual cubre
el **hito 1 (ejecución y distribución)** de [PLAN.md](PLAN.md). El control remoto
está deshabilitado hasta validar que la aplicación distribuida abre en el Mac
del trabajo, tal como requiere el plan.

## Compilar

En el Mac de desarrollo:

```sh
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
