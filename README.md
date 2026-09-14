# tcgimport

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Perfil del cliente

Cada usuario tiene una pantalla **Mi perfil** (ícono de persona en la barra
superior) donde edita su **nombre** y su **WhatsApp**. El correo se muestra
pero no es editable: viene de la cuenta de Google con la que inicia sesión.

El número es solo de Perú: el campo muestra `+51` fijo y el usuario escribe los
9 dígitos (debe empezar con 9). Se guarda normalizado como `+51XXXXXXXXX` en
`users/{uid}.whatsapp`; si alguien pega el número con `+51` o `51` adelante, se
recorta solo.

**Nombre y WhatsApp solo se pueden cambiar una vez cada 24 horas**, contadas
desde `users/{uid}.profileUpdatedAt`. Dentro de esa ventana la pantalla
bloquea los campos y muestra cuánto falta; las reglas de Firestore aplican el
mismo límite del lado del servidor, sin afectar los campos que Google
sincroniza en cada inicio de sesión (correo y foto). Antes de guardar se pide
confirmación con los datos a la vista, porque un error de tipeo en el número
deja al cliente sin poder pedir hasta que pase el día.

**Sin WhatsApp registrado no se puede enviar un pedido.** El bloqueo está en
`OrderService.createOrder` (lanza `MissingWhatsAppException` antes de tocar la
base), y la app lo acompaña por dos lados: un aviso rojo en la pantalla
principal mientras falte el número, y un diálogo al intentar enviar el pedido
que lleva al perfil sin perder el carrito.

El nombre y el WhatsApp se copian al pedido en el momento de crearlo, así que
aparecen en el panel admin y en el reporte "Comprados por entregar" sin tener
que ir a buscar el perfil. Como es una foto del momento, un pedido viejo
conserva el número con el que se hizo.

## Ajuste de precios de un pedido

Los precios de TCGPlayer cambian constantemente, así que el staff puede
reescribir los precios de un pedido ya enviado:

1. **Panel admin → Editar precios**: se edita el precio unitario, el envío del
   vendedor y el vendedor de cada carta. El subtotal, el tax, el margen y el
   envío a Perú se recalculan en vivo con la misma tabla de precios con la que
   se cotizó el pedido originalmente (los pedidos de un admin conservan su
   esquema sin margen y con envío reducido).
2. Al guardar, el pedido pasa al estado **"Ajuste de precio — por confirmar"**.
   No hay email ni notificación push — el cliente ve el aviso la próxima vez
   que abre la app.
3. El cliente entra a la app (pedido activo o historial, también disponible
   cuando la convocatoria está cerrada) y **acepta** el nuevo precio — el
   pedido pasa a **"Precio confirmado"** y recién ahí aparece en la exportación
   de pedidos por comprar — o lo **rechaza**, lo que cancela el pedido y le
   libera el candado para armar uno nuevo.

### Reportes del panel admin

El botón de descarga del panel ofrece dos Excel:

- **Pendientes por comprar**: una fila por carta de los pedidos que el staff
  todavía tiene que comprar en TCGPlayer (pendientes, con precio confirmado o
  pendientes de pago). Los que esperan respuesta a un ajuste de precio quedan
  fuera.
- **Comprados por entregar**: los pedidos en estado "Comprado". Hoja
  *Por entregar* con una fila por pedido (cliente, correo, unidades y total a
  cobrar) y hoja *Detalle* con una fila por carta, agrupada por pedido y
  cerrada con el total de ese pedido, para ir tildando al armar la entrega.

Después de cambiar reglas, desplegarlas con:

```bash
firebase deploy --only firestore:rules
```
