/// Texto único de los Términos y Condiciones / Política de Privacidad.
///
/// La pantalla [TermsScreen] y la página pública `web/terminos.html` muestran
/// este mismo contenido: si se edita aquí, hay que reflejarlo allá (y subir
/// [termsVersion], que es lo que obliga a los usuarios a aceptar de nuevo).
library;

// ─────────────────────────────────────────────────────────────────────────
// ⚠️ COMPLETAR ANTES DE PUBLICAR. Son los únicos datos que faltan; aparecen
// interpolados en el texto de abajo y en web/terminos.html.
// ─────────────────────────────────────────────────────────────────────────
const legalBusinessName = '[completar: razón social]';
const legalTaxId = '[completar: RUC]';
const legalAddress = '[completar: domicilio fiscal]';
const legalContactEmail = '[completar: correo de contacto]';
const legalContactPhone = '[completar: WhatsApp de atención]';
const legalJurisdiction = 'Lima';
const legalDatabaseName = 'Clientes de La Fosa Store';
const legalPublicUrl = 'https://tcgimport-pe.web.app/terminos.html';

/// Se sube cuando el texto cambia de forma sustancial. Un usuario que aceptó
/// una versión anterior vuelve a ver la pantalla de aceptación.
const termsVersion = '1.0';
const termsEffectiveDate = '29 de septiembre de 2026';

class TermsSection {
  final String title;
  final List<String> paragraphs;

  const TermsSection(this.title, this.paragraphs);
}

const termsIntro =
    'Este documento regula el uso de la aplicación de La Fosa Store e '
    'incluye la Política de Privacidad aplicable al tratamiento de los datos '
    'personales de sus usuarios, conforme a la Ley N.° 29733, Ley de '
    'Protección de Datos Personales, y su Reglamento aprobado por Decreto '
    'Supremo N.° 016-2024-JUS, vigente desde el 30 de marzo de 2025.';

const termsSections = <TermsSection>[
  TermsSection('1. Quiénes somos y qué es este servicio', [
    '$legalBusinessName, con RUC $legalTaxId y domicilio en $legalAddress, '
        'Perú (en adelante, «La Fosa Store»), opera esta aplicación como un '
        'servicio de intermediación para la compra e importación de cartas de '
        'juegos coleccionables (TCG) desde vendedores de los Estados Unidos, '
        'principalmente a través de TCGPlayer, hacia el Perú.',
    'La Fosa Store no es el vendedor original de las cartas: actúa por '
        'encargo del usuario, comprando a su nombre y gestionando la '
        'consolidación y el envío hasta el Perú.',
    'Al marcar la casilla de aceptación antes de registrarse, al aceptar '
        'estos términos dentro de la aplicación o al enviar un pedido, el '
        'usuario declara haber leído y aceptado estos Términos y Condiciones '
        'y la Política de Privacidad que forma parte de ellos.',
  ]),
  TermsSection('2. Cuenta de usuario', [
    'El acceso se realiza mediante una cuenta de Google. La Fosa Store no '
        'crea, no conoce ni almacena contraseñas: la autenticación la realiza '
        'Google y la aplicación solo recibe la confirmación de identidad junto '
        'con el nombre, el correo y la foto de perfil asociados a esa cuenta.',
    'El usuario es responsable de la veracidad de los datos que registra y de '
        'mantener vigente su número de contacto. Un número inexacto puede '
        'impedir coordinar el pago o la entrega de su pedido.',
    'El servicio está dirigido a personas mayores de edad. Los menores de '
        'edad solo pueden usarlo con la autorización previa de sus padres o '
        'tutores, quienes consienten el tratamiento de sus datos conforme a la '
        'normativa vigente.',
  ]),
  TermsSection('3. Cómo funciona un pedido', [
    'Los montos que muestra la aplicación son estimados. Se calculan sobre el '
        'precio publicado por el vendedor, un impuesto de venta estimado de '
        'los Estados Unidos, el margen de servicio de La Fosa Store y el costo '
        'de consolidación y envío hacia el Perú.',
    'Los precios en TCGPlayer varían de forma constante. Si al momento de la '
        'compra el precio cambió, el pedido pasa al estado «Ajuste de precio — '
        'por confirmar» y no se compra nada hasta que el usuario acepte '
        'expresamente el nuevo total. Si no está de acuerdo, puede rechazarlo '
        'y el pedido se cancela sin costo alguno.',
    'El pedido se considera confirmado cuando el usuario acepta el total y '
        'cumple con el pago acordado. Los plazos de entrega son estimados y '
        'dependen de terceros —vendedores, servicio de consolidación, aduanas '
        'y mensajería—, por lo que no constituyen una fecha garantizada.',
    'La Fosa Store informará al usuario cualquier costo adicional aplicable '
        'antes de realizar la compra.',
  ]),
  TermsSection('4. Datos personales que tratamos', [
    'Para prestar el servicio, La Fosa Store trata los siguientes datos '
        'personales del usuario:',
    '• Nombre completo, el que el propio usuario registra en su perfil.\n'
        '• Correo electrónico de la cuenta de Google con la que inicia sesión.\n'
        '• Número de teléfono celular con WhatsApp.\n'
        '• Foto de perfil asociada a la cuenta de Google, cuando exista.\n'
        '• Información de sus pedidos: cartas solicitadas, montos, estados y '
        'fechas.',
    'No se solicitan ni se tratan datos sensibles en los términos de la Ley '
        'N.° 29733. No se solicitan datos de tarjetas ni credenciales '
        'bancarias a través de la aplicación.',
  ]),
  TermsSection('5. Finalidad: uso exclusivamente administrativo', [
    'Los datos personales se tratan únicamente con fines administrativos y '
        'operativos, y en concreto para:',
    '• identificar al usuario y asociar sus pedidos a su cuenta;\n'
        '• contactarlo por WhatsApp o por correo electrónico para coordinar el '
        'pago, informarle el estado de su pedido, comunicarle un ajuste de '
        'precio y coordinar la entrega;\n'
        '• cumplir las obligaciones legales, contables y tributarias que '
        'correspondan.',
    'Los datos no se utilizan con fines publicitarios ni promocionales, no se '
        'venden, ceden ni alquilan a terceros con fines comerciales, y no se '
        'emplean para elaborar perfiles ni para adoptar decisiones '
        'automatizadas que afecten al usuario.',
    'Cualquier finalidad distinta a las señaladas requerirá un consentimiento '
        'adicional, previo y específico, que el usuario podrá negar sin que '
        'ello afecte la prestación del servicio.',
  ]),
  TermsSection('6. Consentimiento', [
    'El tratamiento se realiza con el consentimiento libre, previo, expreso, '
        'inequívoco e informado del usuario, otorgado al aceptar estos '
        'términos, conforme a la Ley N.° 29733 y su Reglamento.',
    'El usuario puede revocar su consentimiento en cualquier momento '
        'escribiendo a $legalContactEmail. La revocación no tiene efectos '
        'retroactivos y, dado que los datos indicados son indispensables para '
        'prestar el servicio, su revocación implica el cierre de la cuenta, '
        'sin perjuicio de la conservación de la información necesaria para '
        'atender obligaciones legales o pedidos en curso.',
  ]),
  TermsSection('7. Seguridad y cifrado de la información', [
    'La información se almacena en la plataforma Google Firebase (Google '
        'Cloud Platform) y se protege con las siguientes medidas:',
    '• Cifrado en tránsito: toda comunicación entre la aplicación y los '
        'servidores viaja cifrada mediante TLS/HTTPS.\n'
        '• Cifrado en reposo: la infraestructura de Google Cloud cifra los '
        'datos almacenados con algoritmo AES de 256 bits.\n'
        '• Control de acceso: las reglas de seguridad de la base de datos '
        'permiten que cada usuario lea y modifique únicamente su propia '
        'información; solo el personal administrativo autorizado accede a los '
        'datos necesarios para gestionar los pedidos.\n'
        '• Autenticación federada con Google, sin almacenamiento de '
        'contraseñas por parte de La Fosa Store.',
    'Ningún sistema es completamente infalible. La Fosa Store adopta las '
        'medidas técnicas, organizativas y legales exigidas por la Ley N.° '
        '29733 y su Reglamento. Ante un incidente de seguridad que afecte '
        'datos personales, lo notificará a la Autoridad Nacional de Protección '
        'de Datos Personales dentro de las 48 horas de conocido y comunicará a '
        'los usuarios afectados cuando corresponda, conforme al Decreto '
        'Supremo N.° 016-2024-JUS.',
  ]),
  TermsSection('8. Plazo de conservación', [
    'Los datos se conservan mientras la cuenta del usuario permanezca activa '
        'y, una vez cerrada, durante el plazo necesario para atender '
        'obligaciones legales, contables, tributarias o eventuales reclamos. '
        'Cumplido ese plazo, los datos se eliminan o se anonimizan de forma '
        'irreversible.',
  ]),
  TermsSection('9. Encargado de tratamiento y flujo transfronterizo', [
    'Para operar, La Fosa Store utiliza los servicios de Google LLC '
        '—Firebase Authentication, Cloud Firestore y Firebase Hosting— en '
        'calidad de encargado de tratamiento, actuando bajo sus instrucciones.',
    'Esto implica que los datos se almacenan en servidores ubicados fuera del '
        'territorio peruano. Al aceptar estos términos, el usuario otorga su '
        'consentimiento expreso para dicho flujo transfronterizo de datos '
        'personales, conforme a la Ley N.° 29733, dejando constancia de que el '
        'proveedor mantiene niveles de protección adecuados.',
  ]),
  TermsSection('10. Banco de datos personales', [
    'Los datos indicados forman parte del banco de datos personales '
        'denominado «$legalDatabaseName», cuyo titular es $legalBusinessName, '
        'administrado conforme a la Ley N.° 29733 y su Reglamento.',
  ]),
  TermsSection('11. Derechos del titular de los datos', [
    'El usuario puede ejercer en cualquier momento los derechos reconocidos '
        'por la Ley N.° 29733 y su Reglamento: información, acceso, '
        'actualización, inclusión, rectificación, supresión o cancelación, '
        'impedir el suministro de sus datos, oposición, tratamiento objetivo y '
        'portabilidad.',
    'Para ejercerlos basta escribir a $legalContactEmail desde el correo '
        'registrado en la cuenta, indicando el derecho que desea ejercer. La '
        'solicitud se atiende dentro de los plazos previstos por la normativa '
        'vigente y sin costo alguno.',
    'Si considera que su solicitud no fue atendida, el usuario puede '
        'presentar un reclamo ante la Autoridad Nacional de Protección de '
        'Datos Personales del Ministerio de Justicia y Derechos Humanos.',
  ]),
  TermsSection('12. Comunicaciones', [
    'Al registrar su número de celular, el usuario acepta recibir mensajes de '
        'WhatsApp y correos electrónicos de carácter transaccional '
        'relacionados con sus pedidos: confirmaciones, ajustes de precio, '
        'coordinación de pago y de entrega. Estas comunicaciones forman parte '
        'del servicio contratado y no constituyen publicidad.',
    'La Fosa Store no envía comunicaciones comerciales no solicitadas. '
        'Cualquier envío promocional requerirá un consentimiento adicional y '
        'podrá revocarse en cualquier momento.',
  ]),
  TermsSection('13. Almacenamiento local en el navegador', [
    'La versión web utiliza el almacenamiento local del navegador únicamente '
        'para mantener la sesión iniciada del usuario. No se utilizan cookies '
        'publicitarias ni herramientas de seguimiento de terceros.',
  ]),
  TermsSection('14. Consultas y reclamos', [
    'Cualquier consulta o reclamo puede dirigirse a $legalContactEmail o al '
        'WhatsApp de atención $legalContactPhone.',
    'La Fosa Store atiende los reclamos conforme al Código de Protección y '
        'Defensa del Consumidor, Ley N.° 29571, sin perjuicio del derecho del '
        'usuario de acudir al Indecopi.',
  ]),
  TermsSection('15. Modificaciones de estos términos', [
    'La Fosa Store puede actualizar estos Términos y Condiciones. Cuando el '
        'cambio sea sustancial, se solicitará nuevamente la aceptación dentro '
        'de la aplicación antes de continuar usando el servicio.',
    'La versión vigente está siempre disponible dentro de la aplicación y en '
        '$legalPublicUrl.',
  ]),
  TermsSection('16. Ley aplicable y jurisdicción', [
    'Estos términos se rigen por las leyes de la República del Perú. '
        'Cualquier controversia derivada de su interpretación o ejecución se '
        'somete a los jueces y tribunales del distrito judicial de '
        '$legalJurisdiction, sin perjuicio de los derechos que la normativa de '
        'protección al consumidor reconoce al usuario.',
  ]),
  TermsSection('17. Contacto', [
    '$legalBusinessName\n'
        'RUC: $legalTaxId\n'
        'Domicilio: $legalAddress\n'
        'Correo: $legalContactEmail\n'
        'WhatsApp: $legalContactPhone',
  ]),
];
