# Prueba Bluetooth — 0.2.1

El arranque en el Mac del trabajo ya fue confirmado por el usuario. Ahora se
valida HID directo. Esta build no captura ni bloquea la entrada local.

1. Cierra la versión anterior de InputSwitch y KeyPad en el Mac del trabajo.
2. Descarga el ZIP 0.2.1, descomprime y reemplaza tu copia de InputSwitch.app.
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

## Si aparece un timeout

La 0.2.1 separa el enlace Bluetooth básico, control HID `0x0011`, interrupción
`0x0013` y confirmación de cifrado. El código de la solicitud asíncrona no equivale
al resultado final: el diagnóstico registra también su callback.

- Primero prueba **Conectar HID** y copia el diagnóstico completo si falla.
- Después pulsa **Iniciar prueba SDP** otra vez, conserva seleccionado el Mac
  personal y pulsa **Esperar al Mac personal**. Desde el personal intenta conectar
  al Mac del trabajo en Ajustes > Bluetooth, si el sistema ofrece esa opción.
  Este modo espera hasta 45 s y no abre canales salientes automáticamente.
- Si no aparece una opción para conectar, indícalo. No hace falta borrar otros
  dispositivos ni cambiar servicios Bluetooth del sistema.

Todavía no está determinada la causa del timeout de 0.2.0 ni confirmado que esta
build permita entrada HID en los dos Mac. El objetivo es distinguir dónde falla.

Devuelve el texto de **Copiar diagnóstico** e indica qué acción llegó al personal.
Si la lista está vacía o la vinculación no se completa, indícalo también. Publicar
el servicio, estar emparejado o abrir un canal no prueba por sí solo entrada HID.

El diagnóstico contiene estados y códigos técnicos, no teclas escritas ni nombres
ni direcciones de los dispositivos. Solo se guarda en memoria (100 líneas).

## Límites de este prototipo

- Solo teclado HID de seis teclas y ratón relativo en report protocol. Sin boot,
  funciones multimedia, gestos multitáctiles ni autoconexión.
- Requiere receptor emparejado y enlace cifrado. La apertura del enlace básico solicita autenticación mediante la API pública;
  no se utilizan APIs privadas para cambiar roles Bluetooth.
- Máximo 16 paquetes en cola por canal y una escritura asíncrona pendiente. Timeout
  por etapa de conexión: 12 s; espera entrante: 45 s; confirmación de cifrado: 5 s;
  escritura: 2 s. Los callbacks de sesiones anteriores se descartan.
- Al detener se intenta enviar neutral y se cierra en un máximo de 250 ms. Con el
  enlace perdido o terminación forzada no se garantiza la entrega: debe comprobarse
  que el receptor libera su estado al desconectar.
- Las solicitudes de enlace básico tienen un límite adicional de ocho intentos
  por ejecución.
- Conserva los delegados retirados para callbacks tardíos; tras hasta cuatro
  conexiones completas (ocho canales) pide reiniciar la app. Es un límite deliberado
  de esta build de prueba, no el comportamiento previsto del producto final.
- Captura global, atajo de regreso y selección operativa This Mac / Andrés PC quedan
  para el siguiente hito, después de comprobar entrada real entre los dos Mac.
