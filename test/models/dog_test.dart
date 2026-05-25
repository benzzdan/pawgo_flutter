import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/models/temperament.dart';

void main() {
  test('fromMap parses Supabase row', () {
    final dog = Dog.fromMap({
      'id': 'd1',
      'owner_id': 'o1',
      'name': 'Rex',
      'breed': 'Labrador',
      'weight_kg': 12.5,
      'temperament': 'playful',
      'allergies': ['chicken'],
      'aggression_history': false,
      'vaccination_status': 'approved',
      'vaccination_expires_at': '2027-01-01T00:00:00Z',
    });
    expect(dog.name, 'Rex');
    expect(dog.temperament, Temperament.playful);
    expect(dog.allergies, ['chicken']);
    expect(dog.isVaccinationValid, isTrue);
  });

  test('isVaccinationValid false when status != approved', () {
    final d = Dog.fromMap({
      'id': 'd',
      'owner_id': 'o',
      'name': 'A',
      'breed': 'X',
      'vaccination_status': 'pending_review',
    });
    expect(d.isVaccinationValid, isFalse);
  });

  test('isVaccinationValid false when expired', () {
    final d = Dog.fromMap({
      'id': 'd',
      'owner_id': 'o',
      'name': 'A',
      'breed': 'X',
      'vaccination_status': 'approved',
      'vaccination_expires_at': '2020-01-01T00:00:00Z',
    });
    expect(d.isVaccinationValid, isFalse);
  });
}
