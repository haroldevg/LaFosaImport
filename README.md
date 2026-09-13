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

## Ajuste de precios de un pedido

Los precios de TCGPlayer cambian constantemente, así que el staff puede
reescribir los precios de un pedido ya enviado:

1. **Panel admin → Editar precios**: se edita el precio unitario, el envío del
   vendedor y el vendedor de cada carta. El subtotal, el tax, el margen y el
   envío a Perú se recalculan en vivo con la misma tabla de precios con la que
   se cotizó el pedido originalmente (los pedidos de un admin conservan su
   esquema sin margen y con envío reducido).
2. Al guardar, el pedido pasa al estado **"Ajuste de precio — por confirmar"**
   y se le envía un correo al cliente con el detalle, el total anterior, el
   nuevo y la diferencia.
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

### Envío de correos (requiere una extensión de Firebase)

No hay backend propio: la app encola el correo escribiendo un documento en la
colección `mail`, que entrega la extensión
[**Trigger Email from Firestore**](https://extensions.dev/extensions/firebase/firestore-send-email).
Mientras la extensión no esté instalada, los documentos se acumulan sin
enviarse (el ajuste de precio igual queda registrado y el cliente lo ve en la
app).

Instalación, una sola vez, en el proyecto `tcgimport-pe`:

```bash
firebase ext:install firebase/firestore-send-email --project=tcgimport-pe
```

Parámetros a usar durante la instalación:

- **Email documents collection**: `mail` (debe coincidir con `MailService`).
- **SMTP connection URI**: el SMTP del remitente, por ejemplo
  `smtps://usuario@dominio.com@smtp.gmail.com:465` (con una contraseña de
  aplicación, no la del correo).
- **Default FROM address**: el remitente que verá el cliente.

Si la app se publica en un dominio propio, actualizar `appUrl` en
`lib/services/mail_service.dart` — es el enlace del botón del correo.

Después de cambiar reglas, desplegarlas con:

```bash
firebase deploy --only firestore:rules
```
