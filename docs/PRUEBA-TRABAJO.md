# Prueba de ejecución en el Mac del trabajo

Esta entrega valida exclusivamente el hito 1 del plan. No transmite teclado ni
ratón. No solicita permisos de Accesibilidad ni Bluetooth.

1. Transfiere `InputSwitch-0.1.1-arm64.zip` al Mac del trabajo mediante un medio permitido.
2. Descomprime el ZIP con Finder. Copia `InputSwitch.app` a `~/Applications`
   (la carpeta Applications de tu usuario; créala si no existe).
3. Abre la app. Finder puede mostrarla como `InputSwitch`, ocultando `.app`.
   Debe aparecer el mensaje «InputSwitch se ha abierto correctamente» y un
   teclado con «This Mac» en la barra de menús superior.
4. Cierra el mensaje con «Entendido». Puedes volver a verlo desde el menú
   «Prueba de ejecución…» o haciendo doble clic otra vez en la app.
5. Selecciona «Salir de InputSwitch» y vuelve a abrirla para repetir la prueba.

La firma es local/ad hoc, no Developer ID ni notarizada. Si macOS o una política
corporativa impide abrirla, conserva el mensaje exacto y detén la prueba. No
elimines cuarentena, modifiques Gatekeeper ni instales herramientas de desarrollo
para sortear el bloqueo.

Devuelve estos resultados para continuar con el prototipo Bluetooth:

- Versión de macOS del trabajo y si abrió con el usuario estándar.
- Si apareció el icono, se abrió el diálogo y fue posible salir/reabrir.
- Mensaje exacto si ocurrió un error o solicitó administrador.
- Modelo y versión de macOS del Mac personal; distribución del teclado.

Para desinstalar esta build, sal y elimina la app. No instala servicios ni escribe
preferencias. La app compilada es arm64, con mínimo macOS 15.0. Su ejecución en
Tahoe 26.7 debe validarse físicamente con este ZIP.
