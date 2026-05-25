import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/legal.dart';
import '../config/legal_placeholder.dart';
import '../theme/app_theme.dart';

/// Renders the Terms of Use or Privacy Policy as a scrollable list of
/// sections.
///
/// **No accept button on this screen.** Acceptance happens at sign-up via
/// the checkbox; this screen is read-only and reachable from the inline
/// links there. Just shows the version header and a Back button.
///
/// Locale comes from the surrounding [MaterialApp] / [Localizations];
/// unknown locales fall back to Spanish in [legalSections].
class LegalAcceptanceScreen extends StatelessWidget {
  const LegalAcceptanceScreen({super.key, required this.doc});

  /// Which document to render — Terms or Privacy.
  final LegalDoc doc;

  String _titleFor(LegalDoc d, String lang) {
    if (lang == 'en') {
      return d == LegalDoc.terms ? 'Terms of Use' : 'Privacy Policy';
    }
    return d == LegalDoc.terms ? 'Términos de Uso' : 'Política de Privacidad';
  }

  String _versionPrefixFor(String lang) =>
      lang == 'en' ? 'Version' : 'Versión';

  String _versionFor(LegalDoc d) =>
      d == LegalDoc.terms ? kTermsVersion : kPrivacyVersion;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final sections = legalSections(doc, lang);
    final version = _versionFor(doc);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _titleFor(doc, lang),
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.cacaoBrown,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.cacaoBrown),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ListView.separated(
            itemCount: sections.length + 1,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    '${_versionPrefixFor(lang)} $version',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              final section = sections[index - 1];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    section.body,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
