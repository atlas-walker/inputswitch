# Estado de validación

- Hito 1: usuario confirmó que la build distribuida abre en el otro Mac y muestra
  This Mac en la barra de menús (24 de septiembre de 2026).
- Desarrollo: macOS 15.3.2 arm64, Swift 6.1.2 y SDK macOS 15.5.
- Publicación SDP local: control 0x0011, interrupción 0x0013, IOReturn 0.
  Retirada del servicio: IOReturn 0. Sin cambiar servicios de sistema.
- Tests automatizados: tamaños de informes derivados del descriptor, respuestas
  HIDP, solicitudes truncadas/incorrectas y codificación SDP con el parser de Apple.
- Pendiente en los dos Mac: conexión/cifrado, tecla/clic/movimiento efectivos,
  reconexión, suspensión y liberación ante desconexión. No declarados aprobados.

Implementación independiente. Referencias de API: headers públicos de IOBluetooth
incluidos en SDK macOS 15.5 y documentación de Apple:
https://developer.apple.com/documentation/iobluetooth/iobluetoothsdpdataelement
https://developer.apple.com/documentation/iobluetooth/iobluetoothsdpservicerecord
https://developer.apple.com/documentation/iobluetooth/iobluetoothl2capchannel

Descriptor y mensajes basados en HID report protocol / HIDP. No es una certificación
Bluetooth ni una afirmación de cumplimiento completo de HID 1.1.1.

## Corrección de diagnóstico 0.2.1

El usuario reportó timeout de conexión HID en 0.2.0. No se ha identificado su causa
con ese dato aislado. La 0.2.1 añade apertura asíncrona del enlace básico autenticado,
timeouts independientes por etapa y espera entrante explícita. Mantiene la
comprobación de cifrado antes de habilitar pruebas de entrada.

Los tests verifican también exposición de selectores Objective-C, entrega única
de callbacks y descarte de callbacks después de cancelar/cerrar. No simulan un
radio real ni demuestran que macOS acepte el rol HID.

Referencia de la apertura explícita del enlace básico:
https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/openconnection(_:withpagetimeout:authenticationrequired:)
