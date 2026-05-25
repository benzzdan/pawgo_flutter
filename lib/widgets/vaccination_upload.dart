import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pawgo/l10n/app_localizations.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Owner-facing widget for uploading a dog's vaccination card.
///
/// Renders a status badge (pending / approved / rejected / expired) plus an
/// upload button. The picker accepts JPG/PNG/PDF and validates file size
/// up to 10 MB; the actual upload to the `dog-vaccinations` bucket is
/// performed by the parent screen (it owns the dog id and Supabase client).
class VaccinationUpload extends StatelessWidget {
  final File? localFile;
  final String? remoteUrl;
  // pending_review | approved | rejected | expired
  final String status;
  final ValueChanged<File> onPicked;

  const VaccinationUpload({
    super.key,
    required this.localFile,
    required this.remoteUrl,
    required this.status,
    required this.onPicked,
  });

  static const int _maxBytes = 10 * 1024 * 1024;

  Future<void> _pick(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    final file = File(path);
    final size = await file.length();
    if (size > _maxBytes) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max 10MB')),
      );
      return;
    }
    onPicked(file);
  }

  Color _badgeColor() {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _badgeText(AppLocalizations l) {
    switch (status) {
      case 'approved':
        return l.vaccinationApproved;
      case 'rejected':
        return l.vaccinationRejected;
      case 'expired':
        return l.vaccinationExpired;
      default:
        return l.vaccinationPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasUpload = localFile != null || remoteUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _badgeColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _badgeText(l10n),
            style: TextStyle(
              color: _badgeColor(),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          icon: const Icon(PhosphorIconsRegular.upload),
          label: Text(hasUpload ? 'Reemplazar' : 'Subir cartilla'),
          onPressed: () => _pick(context),
        ),
      ],
    );
  }
}
