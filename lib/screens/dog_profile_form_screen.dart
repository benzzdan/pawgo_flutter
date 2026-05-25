import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/models/temperament.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/mood_picker.dart';
import 'package:pawgo/widgets/vaccination_upload.dart';

/// Full dog health profile editor. Covers Feature 1 (mandatory health fields)
/// and Feature 2 (mood picker). Replaces the inline dog form previously
/// embedded in `my_dogs_screen.dart`.
///
/// The screen accepts an optional initial [Dog] to edit. When [Dog.id] is
/// `_new`, it inserts a fresh row; otherwise it updates the existing row.
/// Vaccination uploads happen after the row exists, so we always know the
/// `dog_id` segment of the storage path.
class DogProfileFormScreen extends StatefulWidget {
  /// When non-null, the form is in "edit" mode and prefills all controllers.
  /// When null, a fresh dog row is inserted on submit.
  final Dog? initial;
  const DogProfileFormScreen({super.key, this.initial});

  @override
  State<DogProfileFormScreen> createState() => _DogProfileFormScreenState();
}

class _DogProfileFormScreenState extends State<DogProfileFormScreen> {
  final _supa = Supabase.instance.client;
  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _breed;
  late final TextEditingController _weight;
  late final TextEditingController _vetName;
  late final TextEditingController _vetClinic;
  late final TextEditingController _vetPhone;
  late final TextEditingController _ecName;
  late final TextEditingController _ecRel;
  late final TextEditingController _ecPhone;
  late final TextEditingController _allergies;
  late final TextEditingController _aggrNotes;

  Temperament? _temperament;
  bool _aggressionHistory = false;
  File? _vaccinationFile;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name);
    _breed = TextEditingController(text: i?.breed);
    _weight = TextEditingController(text: i?.weightKg?.toString());
    _vetName = TextEditingController(text: i?.vetName);
    _vetClinic = TextEditingController(text: i?.vetClinic);
    _vetPhone = TextEditingController(text: i?.vetPhone);
    _ecName = TextEditingController(text: i?.emergencyContactName);
    _ecRel = TextEditingController(text: i?.emergencyContactRelationship);
    _ecPhone = TextEditingController(text: i?.emergencyContactPhone);
    _allergies = TextEditingController(text: i?.allergies.join(', '));
    _aggrNotes = TextEditingController(text: i?.aggressionNotes);
    _temperament = i?.temperament;
    _aggressionHistory = i?.aggressionHistory ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _vetName.dispose();
    _vetClinic.dispose();
    _vetPhone.dispose();
    _ecName.dispose();
    _ecRel.dispose();
    _ecPhone.dispose();
    _allergies.dispose();
    _aggrNotes.dispose();
    super.dispose();
  }

  Future<String?> _uploadVaccination(String dogId) async {
    final file = _vaccinationFile;
    if (file == null) return widget.initial?.vaccinationCardUrl;
    final ownerId = _supa.auth.currentUser!.id;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$ownerId/$dogId/$ts.$ext';
    await _supa.storage.from('dog-vaccinations').upload(path, file);
    return path;
  }

  /// Strips commas/whitespace from the allergies field and returns
  /// a clean list. Empty input becomes an empty list (which the DB
  /// stores as `'{}'` per the migration default).
  List<String> _parseAllergies(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> _buildBasePayload(String ownerId) => {
        'owner_id': ownerId,
        'name': _name.text.trim(),
        'breed': _breed.text.trim(),
        'weight_kg': double.tryParse(_weight.text.trim()),
        'temperament': _temperament!.dbValue,
        'aggression_history': _aggressionHistory,
        'aggression_notes':
            _aggressionHistory ? _aggrNotes.text.trim() : null,
        'allergies': _parseAllergies(_allergies.text),
        'vet_name': _vetName.text.trim(),
        'vet_clinic': _vetClinic.text.trim(),
        'vet_phone': _vetPhone.text.trim(),
        'emergency_contact_name': _ecName.text.trim(),
        'emergency_contact_relationship': _ecRel.text.trim(),
        'emergency_contact_phone': _ecPhone.text.trim(),
      };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_temperament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un temperamento')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ownerId = _supa.auth.currentUser!.id;
      final payload = _buildBasePayload(ownerId);

      // Step 1: insert or update the row to obtain a dog id.
      late final String dogId;
      if (_isEditing) {
        dogId = widget.initial!.id;
        payload.remove('owner_id');
        await _supa.from('dogs').update(payload).eq('id', dogId);
      } else {
        final inserted = await _supa
            .from('dogs')
            .insert(payload)
            .select('id')
            .single();
        dogId = inserted['id'] as String;
      }

      // Step 2: upload the vaccination card now that we know dogId, then
      // patch the storage path + status onto the row.
      if (_vaccinationFile != null) {
        final vaxPath = await _uploadVaccination(dogId);
        await _supa.from('dogs').update({
          'vaccination_card_url': vaxPath,
          'vaccination_uploaded_at': DateTime.now().toIso8601String(),
          'vaccination_status': 'pending_review',
        }).eq('id', dogId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(context, e, screen: 'dog_profile_form');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  String? _weightValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Número requerido';
    if (n < 0.5 || n > 100) return 'Entre 0.5 y 100 kg';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar perro' : 'Perfil del perro'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(labelText: 'Raza'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
              validator: _weightValidator,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Temperamento',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            MoodPicker(
              value: _temperament,
              onChanged: (t) => setState(() => _temperament = t),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _aggressionHistory,
              title: const Text('Historial de agresión'),
              onChanged: (v) => setState(() => _aggressionHistory = v),
            ),
            if (_aggressionHistory)
              TextFormField(
                controller: _aggrNotes,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Notas sobre agresión'),
                validator: _requiredValidator,
              ),
            TextFormField(
              controller: _allergies,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alergias (separadas por coma)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Veterinario',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextFormField(
              controller: _vetName,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _vetClinic,
              decoration: const InputDecoration(labelText: 'Clínica'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _vetPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Contacto de emergencia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextFormField(
              controller: _ecName,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _ecRel,
              decoration: const InputDecoration(labelText: 'Relación'),
              validator: _requiredValidator,
            ),
            TextFormField(
              controller: _ecPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Cartilla de vacunación',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            VaccinationUpload(
              localFile: _vaccinationFile,
              remoteUrl: widget.initial?.vaccinationCardUrl,
              status: widget.initial?.vaccinationStatus ?? 'pending_review',
              onPicked: (f) => setState(() => _vaccinationFile = f),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
