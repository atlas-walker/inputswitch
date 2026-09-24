# Prueba Bluetooth — 0.2.0

El arranque en el Mac del trabajo ya fue confirmado por el usuario. Ahora se
valida HID directo. Esta build no captura ni bloquea la entrada local.

1. Cierra la versión anterior de InputSwitch y KeyPad en el Mac del trabajo.
2. Descarga el ZIP 0.2.0, descomprime y reemplaza tu copia de InputSwitch.app.
3. Abre la app en el Mac del trabajo. Abre «Prueba Bluetooth…» si la ventana no aparece.
4. Pulsa **Iniciar prueba SDP**. Si macOS solicita Bluetooth, autorízalo para esta
   prueba si tu usuario puede hacerlo. Si lo bloquea, copia el mensaje exacto.
5. El diagnóstico debe indicar control `0x0011`, interrupción `0x0013` y
   **PUBLICACIÓN CORRECTA**. Otro resultado es un dato de diagnóstico, no éxito.
6. Empareja ambos Mac desde Ajustes del Sistema > Bluetooth si no estaban
   emparejados. La app no cambia la visibilidad del equipo ni empareja en secreto.
   Puede aparecer el nombre del Mac emisor, no «InputSwitch».
7. Pulsa **Actualizar dispositivos** y selecciona explícitamente el Mac personal.
   No selecciones tus auriculares, ratón u otros accesorios. Pulsa **Conectar HID**.
8. Si aparece **CANALES LISTOS**, abre una ventana de texto vacía en el personal.
   Pulsa **Probar tecla A** y confirma. Hay 3 segundos para poner foco en la ventana
   del personal. Debe aparecer una `a` (según el layout) y no repetirse indefinidamente.
9. Prueba **Mover puntero**. Para **Probar clic**, coloca primero el puntero sobre
   una zona vacía y sin botones del editor. Cada acción incluye liberación.
10. Pulsa **Detener**, vuelve a iniciar y repite la conexión. Después prueba cerrar
    la app y suspender. El teclado y trackpad del trabajo siguen siempre locales.

Devuelve el texto de **Copiar diagnóstico** e indica qué acción llegó al personal.
Si la lista está vacía o la vinculación no se completa, indícalo también. Publicar
el servicio, estar emparejado o abrir un canal no prueba por sí solo entrada HID.

El diagnóstico contiene estados y códigos técnicos, no teclas escritas ni nombres
ni direcciones de los dispositivos. Solo se guarda en memoria (100 líneas).

## Límites de este prototipo

- Solo teclado HID de seis teclas y ratón relativo en report protocol. Sin boot,
  funciones multimedia, gestos multitáctiles ni autoconexión.
- Requiere receptor emparejado y enlace cifrado. La app no fuerza autenticación ni
  utiliza APIs privadas para cambiar roles Bluetooth.
- Máximo 16 paquetes en cola por canal y una escritura asíncrona pendiente. Timeout
  de conexión: 12 s; escritura: 2 s. Los callbacks de sesiones anteriores se descartan.
- Al detener se intenta enviar neutral y se cierra en un máximo de 250 ms. Con el
  enlace perdido o terminación forzada no se garantiza la entrega: debe comprobarse
  que el receptor libera su estado al desconectar.
- Conserva los delegados retirados para callbacks tardíos; tras hasta cuatro
  conexiones completas (ocho canales) pide reiniciar la app. Es un límite deliberado
  de esta build de prueba, no el comportamiento previsto del producto final.
- Captura global, atajo de regreso y selección operativa This Mac / Andrés PC quedan
  para el siguiente hito, después de comprobar entrada real entre los dos Mac.
