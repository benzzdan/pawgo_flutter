import 'package:pawgo/models/temperament.dart';

/// Typed representation of a `public.dogs` row.
///
/// `fromMap` is tolerant of partial Supabase rows: it defaults
/// missing fields to safe values so a freshly inserted dog (or a
/// SELECT that doesn't include every column) still parses.
class Dog {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final double? weightKg;
  final Temperament? temperament;
  final bool aggressionHistory;
  final String? aggressionNotes;
  final List<String> allergies;
  final String? allergiesNotes;
  final String? vetName;
  final String? vetClinic;
  final String? vetPhone;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;
  final String? vaccinationCardUrl;
  final String vaccinationStatus;
  final DateTime? vaccinationExpiresAt;
  final String? photoUrl;

  const Dog({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    this.weightKg,
    this.temperament,
    this.aggressionHistory = false,
    this.aggressionNotes,
    this.allergies = const [],
    this.allergiesNotes,
    this.vetName,
    this.vetClinic,
    this.vetPhone,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
    this.vaccinationCardUrl,
    this.vaccinationStatus = 'pending_review',
    this.vaccinationExpiresAt,
    this.photoUrl,
  });

  factory Dog.fromMap(Map<String, dynamic> m) => Dog(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: m['name'] as String,
        breed: (m['breed'] as String?) ?? '',
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        temperament: Temperament.fromDb(m['temperament'] as String?),
        aggressionHistory: (m['aggression_history'] as bool?) ?? false,
        aggressionNotes: m['aggression_notes'] as String?,
        allergies: List<String>.from((m['allergies'] as List?) ?? const []),
        allergiesNotes: m['allergies_notes'] as String?,
        vetName: m['vet_name'] as String?,
        vetClinic: m['vet_clinic'] as String?,
        vetPhone: m['vet_phone'] as String?,
        emergencyContactName: m['emergency_contact_name'] as String?,
        emergencyContactRelationship:
            m['emergency_contact_relationship'] as String?,
        emergencyContactPhone: m['emergency_contact_phone'] as String?,
        vaccinationCardUrl: m['vaccination_card_url'] as String?,
        vaccinationStatus:
            (m['vaccination_status'] as String?) ?? 'pending_review',
        vaccinationExpiresAt: m['vaccination_expires_at'] == null
            ? null
            : DateTime.parse(m['vaccination_expires_at'] as String),
        photoUrl: m['photo_url'] as String?,
      );

  /// True iff the vaccination is currently approved and not expired.
  /// A null `vaccinationExpiresAt` means "no expiry set" (still valid).
  bool get isVaccinationValid {
    if (vaccinationStatus != 'approved') return false;
    final exp = vaccinationExpiresAt;
    if (exp != null && !exp.isAfter(DateTime.now())) return false;
    return true;
  }
}
