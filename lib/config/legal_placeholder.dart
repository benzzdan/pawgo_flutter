/// Placeholder bilingual T&C and Privacy text bodies.
///
/// **TODO(legal):** the strings below are *placeholders only*. Legal must
/// replace each entry with the approved Spanish + English copy before V1
/// public release. The structure (section title + paragraph) can change —
/// just keep the locale → list-of-sections shape and update consumers.
///
/// Consumers:
/// - [legalSections] returns the sections to render for a given doc + locale
/// - [LegalDoc] selects between Terms of Use and Privacy Policy
library;

/// Which legal document a screen is rendering.
enum LegalDoc { terms, privacy }

/// One renderable section of a legal doc.
class LegalSection {
  /// Heading for the section, e.g. "Use of Service".
  final String title;

  /// Body paragraph. Multi-paragraph sections should be split into multiple
  /// [LegalSection]s so the screen can lay them out consistently.
  final String body;

  const LegalSection({required this.title, required this.body});
}

/// Returns the placeholder sections for [doc] in the requested [languageCode]
/// (`'es'` or `'en'`). Unknown locales fall back to Spanish (primary market).
List<LegalSection> legalSections(LegalDoc doc, String languageCode) {
  final lang = languageCode == 'en' ? 'en' : 'es';
  switch (doc) {
    case LegalDoc.terms:
      return lang == 'en' ? _termsEn : _termsEs;
    case LegalDoc.privacy:
      return lang == 'en' ? _privacyEn : _privacyEs;
  }
}

// ---------------------------------------------------------------------------
// PLACEHOLDER COPY — replace with approved legal text before V1 release.
// ---------------------------------------------------------------------------

const List<LegalSection> _termsEs = [
  LegalSection(
    title: 'TODO LEGAL: Aceptación de los Términos',
    body:
        'Texto provisional. Al usar Pawgo aceptas estos Términos. La versión '
        'final será sustituida por el equipo legal antes del lanzamiento.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Uso del Servicio',
    body:
        'Texto provisional. Pawgo conecta dueños de perros con paseadores '
        'verificados. El uso del servicio implica el cumplimiento de las '
        'normas de la comunidad.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cuentas y Registro',
    body:
        'Texto provisional. Debes proporcionar información veraz al crear '
        'tu cuenta y eres responsable de mantener su seguridad.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Pagos y Tarifas',
    body:
        'Texto provisional. Pawgo cobra una comisión del 18% sobre cada '
        'paseo. Los pagos se procesan a través del proveedor que aparece en '
        'la pantalla de pago.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cancelaciones y Reembolsos',
    body:
        'Texto provisional. Los términos de cancelación y reembolso se '
        'mostrarán en la pantalla de reserva al confirmar cada paseo.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Conducta del Usuario',
    body:
        'Texto provisional. No se permiten conductas abusivas, fraudulentas '
        'o ilegales en la plataforma.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Propiedad Intelectual',
    body:
        'Texto provisional. El nombre, logotipo y diseño de Pawgo son '
        'propiedad de la empresa.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Limitación de Responsabilidad',
    body:
        'Texto provisional. Pawgo no es responsable de los daños indirectos '
        'derivados del uso del servicio, salvo lo que exija la ley aplicable.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cambios en los Términos',
    body:
        'Texto provisional. Podemos actualizar estos Términos. Te '
        'notificaremos los cambios relevantes dentro de la aplicación.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Contacto',
    body:
        'Texto provisional. Para cualquier duda escribe a soporte@pawgo.app.',
  ),
];

const List<LegalSection> _termsEn = [
  LegalSection(
    title: 'TODO LEGAL: Acceptance of Terms',
    body:
        'Placeholder text. By using Pawgo you accept these Terms. Final copy '
        'will be supplied by the legal team before launch.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Use of Service',
    body:
        'Placeholder text. Pawgo connects dog owners with verified walkers. '
        'Using the service means agreeing to the community guidelines.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Accounts and Registration',
    body:
        'Placeholder text. You must provide accurate information when '
        'creating your account and are responsible for keeping it secure.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Payments and Fees',
    body:
        'Placeholder text. Pawgo charges an 18% commission on each walk. '
        'Payments are processed through the provider shown on the checkout '
        'screen.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cancellations and Refunds',
    body:
        'Placeholder text. Cancellation and refund terms are displayed on '
        'the booking screen when each walk is confirmed.',
  ),
  LegalSection(
    title: 'TODO LEGAL: User Conduct',
    body:
        'Placeholder text. Abusive, fraudulent, or illegal behavior on the '
        'platform is not allowed.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Intellectual Property',
    body:
        'Placeholder text. The Pawgo name, logo, and design are owned by '
        'the company.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Limitation of Liability',
    body:
        'Placeholder text. Pawgo is not liable for indirect damages arising '
        'from use of the service, except as required by applicable law.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Changes to Terms',
    body:
        'Placeholder text. We may update these Terms. We will notify you of '
        'material changes inside the app.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Contact',
    body:
        'Placeholder text. For any questions write to support@pawgo.app.',
  ),
];

const List<LegalSection> _privacyEs = [
  LegalSection(
    title: 'TODO LEGAL: Resumen de Privacidad',
    body:
        'Texto provisional. Esta política describe qué datos recopila Pawgo '
        'y cómo los utiliza. El equipo legal sustituirá este contenido.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Información que Recopilamos',
    body:
        'Texto provisional. Recopilamos datos de cuenta, ubicación durante '
        'paseos activos, mensajes de chat y métricas de uso de la app.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cómo Usamos tus Datos',
    body:
        'Texto provisional. Usamos tus datos para operar el servicio, '
        'mejorarlo, prevenir fraude y cumplir obligaciones legales.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Compartición de Datos',
    body:
        'Texto provisional. Compartimos datos mínimos con proveedores de '
        'pagos, verificación de identidad y notificaciones para entregar el '
        'servicio.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Ubicación en Tiempo Real',
    body:
        'Texto provisional. La ubicación del paseador sólo se transmite '
        'durante un paseo activo y sólo se comparte con el dueño asociado.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Almacenamiento y Seguridad',
    body:
        'Texto provisional. Aplicamos medidas razonables para proteger tu '
        'información, pero ninguna transmisión por Internet es 100% segura.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Tus Derechos',
    body:
        'Texto provisional. Puedes solicitar acceso, corrección o '
        'eliminación de tus datos personales escribiendo a privacidad@pawgo.app.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Retención',
    body:
        'Texto provisional. Conservamos los datos por el tiempo necesario '
        'para prestar el servicio y cumplir obligaciones legales.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Menores de Edad',
    body:
        'Texto provisional. Pawgo no está dirigido a menores de 18 años.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Cambios en la Política',
    body:
        'Texto provisional. Podemos actualizar esta política. Te '
        'notificaremos los cambios relevantes dentro de la aplicación.',
  ),
];

const List<LegalSection> _privacyEn = [
  LegalSection(
    title: 'TODO LEGAL: Privacy Summary',
    body:
        'Placeholder text. This policy describes what data Pawgo collects '
        'and how it is used. Legal will replace this content.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Information We Collect',
    body:
        'Placeholder text. We collect account data, location during active '
        'walks, chat messages, and app usage metrics.',
  ),
  LegalSection(
    title: 'TODO LEGAL: How We Use Your Data',
    body:
        'Placeholder text. We use your data to operate the service, improve '
        'it, prevent fraud, and meet legal obligations.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Data Sharing',
    body:
        'Placeholder text. We share minimal data with payment, identity-'
        'verification, and notification providers to deliver the service.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Real-time Location',
    body:
        'Placeholder text. A walker\'s location is only transmitted during '
        'an active walk and is only shared with the associated owner.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Storage and Security',
    body:
        'Placeholder text. We apply reasonable measures to protect your '
        'information, but no Internet transmission is 100% secure.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Your Rights',
    body:
        'Placeholder text. You can request access, correction, or deletion '
        'of your personal data by writing to privacy@pawgo.app.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Retention',
    body:
        'Placeholder text. We keep your data only as long as needed to '
        'provide the service and meet legal obligations.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Minors',
    body: 'Placeholder text. Pawgo is not directed to people under 18.',
  ),
  LegalSection(
    title: 'TODO LEGAL: Changes to this Policy',
    body:
        'Placeholder text. We may update this policy. We will notify you of '
        'material changes inside the app.',
  ),
];
