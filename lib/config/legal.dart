/// Legal-document versioning + canonical URLs.
///
/// When you change the placeholder text or the published legal docs, bump
/// these version strings. The sign-up screen writes the *current* version
/// into `users.terms_version` / `users.privacy_version` so a future
/// re-prompt can compare against what the user previously accepted.
///
/// Format is intentionally open (any TEXT) — using ISO date strings keeps
/// the values both human-readable and naturally orderable.
library;

/// Current Terms of Use version the app prompts new users with.
const String kTermsVersion = '2026-05-25';

/// Current Privacy Policy version the app prompts new users with.
const String kPrivacyVersion = '2026-05-25';

/// Canonical Terms of Use URL (used only for inline links once the docs are
/// hosted; the in-app screen reads from `legal_placeholder.dart` until then).
const String kTermsUrl = 'https://pawgo.app/legal/terms';

/// Canonical Privacy Policy URL (see kTermsUrl note).
const String kPrivacyUrl = 'https://pawgo.app/legal/privacy';
