# InputSwitch — build lista para usar (v0.1.1, arm64)

Esta carpeta contiene la app **ya compilada**. No necesitas Swift, Xcode ni
Command Line Tools en el Mac donde la vayas a correr (solo un Mac con chip Apple
Silicon / arm64 y macOS 15.0 o superior).

## Archivos

- `InputSwitch-0.1.1-arm64.zip` — la app empaquetada.
- `InputSwitch-0.1.1-arm64.zip.sha256` — suma de verificación.
- `build-environment.txt` — toolchain con el que se compiló.

## Cómo correrla en el otro MacBook

1. Descarga `InputSwitch-0.1.1-arm64.zip` desde GitHub (botón **Download raw**
   o clona el repo).
2. En Terminal, dentro de la carpeta donde quedó el ZIP:

   ```sh
   # (opcional) verificar integridad
   shasum -a 256 -c InputSwitch-0.1.1-arm64.zip.sha256

   # descomprimir
   unzip InputSwitch-0.1.1-arm64.zip

   # quitar la marca de "descargado de internet" (firma ad-hoc)
   xattr -dr com.apple.quarantine InputSwitch.app

   # abrir
   open InputSwitch.app
   ```

Si al abrir macOS muestra un aviso de seguridad, ve a **Ajustes del Sistema →
Privacidad y seguridad** y pulsa **Abrir de todos modos**. Esto ocurre porque la
firma es ad-hoc (sin cuenta de desarrollador de pago).
