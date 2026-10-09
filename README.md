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

## Comisión de servicio

Cada **unidad** comprada paga una comisión, elegida por el precio unitario de
la carta antes de sumarle nada (`lib/services/pricing_config.dart`):

| Precio unitario | Comisión por unidad |
|---|---|
| \$0.10 a \$3.33 | \$0.40 fija |
| \$3.34 a \$30.00 | 12% del precio |
| Más de \$30.00 | \$3.60 + 7.5% de lo que pase de \$30.00 |

La tarifa fija de \$0.40 es el mínimo por carta: rige hasta el precio en que el
12% la alcanza (\$3.33). Pasados \$30 el porcentaje es marginal, así que la
comisión nunca baja al subir el precio de una carta.

**Compras grandes:** cuando el subtotal (cartas + envío del vendedor) pasa de
\$150, la porción hasta \$150 paga la tabla por unidad (prorrateada) y lo que
pasa de \$150 paga 7.5%. Es continuo en el umbral: sumar una carta nunca baja
la comisión total del pedido.

Por debajo de \$0.10 **no hay comisión definida**: el formulario de alta
rechaza esos precios y el carrito no deja enviar el pedido, porque cobrar cero
sería inventar un precio que la tabla no fija.

La comisión reemplazó al margen escalonado por porcentaje. El resto del
cálculo no cambió: el total sigue siendo subtotal (cartas + envío del
vendedor) + tax estimado 10% + comisión + envío a Perú por unidad. Los admins
no pagan comisión y pagan envío reducido.

En Firestore la comisión se guarda en `estimatedMargin`, el nombre que tenía
cuando era un margen; se mantuvo para no migrar los pedidos existentes.

## Términos y Condiciones

El texto vive en un solo lugar, `lib/legal/terms.dart`, con los datos de la
empresa (razón social, RUC, domicilio, correo, WhatsApp) como constantes al
inicio del archivo — **hay que completarlos antes de publicar**. La página
pública `web/terminos.html` repite el mismo contenido en HTML plano y se sirve
en `/terminos.html` sin cargar la app; si se edita uno, hay que editar el otro.

`termsVersion` es lo que gobierna la aceptación: cada usuario guarda en
`users/{uid}` la versión que aceptó (`termsAcceptedVersion`) y la fecha
(`termsAcceptedAt`). Subir esa constante hace que **todos** vuelvan a ver la
pantalla de aceptación antes de poder seguir usando la app.

Se pide el consentimiento en tres momentos:

1. **Antes de registrarse**: casilla obligatoria en el login, con enlace al
   texto completo. Mientras no esté marcada, el botón de Google queda
   bloqueado.
2. **Después de registrarse**: `_AccessGate` no deja pasar a nadie —cliente o
   admin— sin una aceptación registrada de la versión vigente; la pantalla
   solo ofrece "Acepto" o "Cerrar sesión".
3. **Antes de pedir**: `createOrder` lanza `TermsNotAcceptedException` si el
   perfil no tiene la aceptación, para que la regla valga sobre los datos y no
   solo sobre la navegación.

Ya aceptado, el texto sigue disponible desde **Mi perfil**, junto con la
constancia de qué versión aceptó esa persona y cuándo.

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

## Un pedido a la vez (hasta que se compre)

Un cliente no puede tener dos pedidos abiertos mientras el primero todavía
puede cambiar. Los estados que **bloquean** un pedido nuevo son *Pendiente*,
*Ajuste de precio — por confirmar*, *Precio confirmado* y *Pedido confirmado
(Pendiente de pago)*; ver `OrderStatusX.blocksNewOrders`.

Apenas el staff lo marca como **Comprado** —y de ahí en adelante: *Enviado*,
*En tránsito*, *Entregado*, *Cancelado*— el candado se libera y el cliente
puede armar otro mientras el anterior sigue su curso.

El candado es `users/{uid}.activeOrderId`: se toma dentro de una transacción
al crear el pedido y lo suelta `updateOrderStatus` cuando el estado nuevo deja
de bloquear. Las reglas de Firestore exigen lo mismo del lado del servidor —
solo se puede soltar un candado que apunte a un pedido ya comprado o
posterior, así que nadie puede saltarse el límite escribiendo el documento a
mano.

La pantalla principal muestra el **último pedido** mientras siga en curso (no
el que tiene el candado), así que un pedido ya comprado se sigue viendo ahí
mientras viaja, con el botón de "Nuevo pedido" al lado.

## Ajuste de precios de un pedido

Los precios de TCGPlayer cambian constantemente, así que el staff puede
reescribir los precios de un pedido ya enviado:

1. **Panel admin → Editar precios**: se edita el precio unitario, el envío del
   vendedor, el vendedor y la **cantidad** de cada carta. Cualquiera de esos
   cambios rehace en vivo el subtotal, el tax, la comisión de servicio (que
   puede cambiar de tramo, o pasar a 7.5% en la parte que cruce los \$150) y el
   envío a Perú, que depende de la cantidad total de unidades. Se usa la
   tabla vigente hoy, con el esquema con el que se cotizó el pedido (los
   pedidos de un admin conservan su esquema sin comisión y con envío
   reducido).
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

## Desplegar la versión web

Compilar siempre con `--no-tree-shake-icons`:

```bash
flutter build web --release --no-tree-shake-icons
firebase deploy --only hosting
```

El recorte automático de íconos de Flutter Web (activado por defecto en
`--release`) llegó a descartar por error un ícono que sí se usaba
(`Icons.person_outline`, el de "Mi perfil"): el botón seguía ahí y
funcionando, pero invisible. Desactivar el recorte cuesta un poco más de peso
en el bundle (la fuente de íconos completa en vez del subconjunto recortado),
pero evita que esto se repita con cualquier ícono a futuro.
