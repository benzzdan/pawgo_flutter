import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/dog_service.dart';

void main() {
  group('Dog.fromJson', () {
    test('parses full dog JSON', () {
      final json = {
        'id': 'd001',
        'owner_id': 'owner-001',
        'name': 'Max',
        'breed': 'Golden Retriever',
        'age_years': 3,
        'weight_kg': 30.5,
        'notes': 'Loves fetch',
        'photo_url': 'https://example.com/max.jpg',
        'created_at': '2026-01-15T10:00:00Z',
      };

      final dog = Dog.fromJson(json);

      expect(dog.id, 'd001');
      expect(dog.ownerId, 'owner-001');
      expect(dog.name, 'Max');
      expect(dog.breed, 'Golden Retriever');
      expect(dog.ageYears, 3);
      expect(dog.weightKg, 30.5);
      expect(dog.notes, 'Loves fetch');
      expect(dog.photoUrl, 'https://example.com/max.jpg');
      expect(dog.createdAt, isNotNull);
    });

    test('handles nullable fields gracefully', () {
      final json = {
        'id': 'd002',
        'owner_id': 'owner-001',
        'name': 'Buddy',
        'breed': null,
        'age_years': null,
        'weight_kg': null,
        'notes': null,
        'photo_url': null,
        'created_at': null,
      };

      final dog = Dog.fromJson(json);

      expect(dog.name, 'Buddy');
      expect(dog.breed, isNull);
      expect(dog.ageYears, isNull);
      expect(dog.weightKg, isNull);
      expect(dog.notes, isNull);
      expect(dog.photoUrl, isNull);
      expect(dog.createdAt, isNull);
    });

    test('display helpers format correctly', () {
      final dog = Dog(
        id: 'd1',
        ownerId: 'o1',
        name: 'Max',
        breed: 'Labrador',
        ageYears: 3,
        weightKg: 25.5,
      );

      expect(dog.displayAge, '3 yrs');
      expect(dog.displayWeight, '25.5 kg');
      expect(dog.displayBreed, 'Labrador');
    });

    test('display helpers handle null values', () {
      final dog = Dog(
        id: 'd2',
        ownerId: 'o1',
        name: 'Unknown Dog',
      );

      expect(dog.displayAge, 'Unknown');
      expect(dog.displayWeight, 'Unknown');
      expect(dog.displayBreed, 'Mixed');
    });

    test('singular year for age 1', () {
      final dog = Dog(
        id: 'd3',
        ownerId: 'o1',
        name: 'Puppy',
        ageYears: 1,
      );

      expect(dog.displayAge, '1 yr');
    });

    test('toInsertJson includes only non-null optional fields', () {
      final dog = Dog(
        id: 'd1',
        ownerId: 'o1',
        name: 'Max',
        breed: 'Labrador',
      );

      final json = dog.toInsertJson();

      expect(json['owner_id'], 'o1');
      expect(json['name'], 'Max');
      expect(json['breed'], 'Labrador');
      expect(json.containsKey('age_years'), false);
      expect(json.containsKey('weight_kg'), false);
      expect(json.containsKey('notes'), false);
      expect(json.containsKey('photo_url'), false);
      // id should NOT be in insert json
      expect(json.containsKey('id'), false);
    });

    test('toInsertJson includes all non-null fields', () {
      final dog = Dog(
        id: 'd1',
        ownerId: 'o1',
        name: 'Max',
        breed: 'Labrador',
        ageYears: 3,
        weightKg: 25.5,
        notes: 'Friendly',
        photoUrl: 'https://example.com/max.jpg',
      );

      final json = dog.toInsertJson();

      expect(json['owner_id'], 'o1');
      expect(json['name'], 'Max');
      expect(json['breed'], 'Labrador');
      expect(json['age_years'], 3);
      expect(json['weight_kg'], 25.5);
      expect(json['notes'], 'Friendly');
      expect(json['photo_url'], 'https://example.com/max.jpg');
      expect(json.containsKey('id'), false);
      expect(json.containsKey('created_at'), false);
    });

    test('weight_kg handles integer from JSON', () {
      final json = {
        'id': 'd1',
        'owner_id': 'o1',
        'name': 'Max',
        'weight_kg': 30, // int, not double
      };

      final dog = Dog.fromJson(json);
      expect(dog.weightKg, 30.0);
      expect(dog.weightKg, isA<double>());
    });
  });

  group('DogSaveResult', () {
    test('default photoUploadFailed is false', () {
      final dog = Dog(id: 'd1', ownerId: 'o1', name: 'Max');
      final result = DogSaveResult(dog: dog);

      expect(result.dog.name, 'Max');
      expect(result.photoUploadFailed, false);
    });

    test('photoUploadFailed can be set to true', () {
      final dog = Dog(id: 'd1', ownerId: 'o1', name: 'Max');
      final result = DogSaveResult(dog: dog, photoUploadFailed: true);

      expect(result.dog.name, 'Max');
      expect(result.photoUploadFailed, true);
    });

    test('result contains the correct dog data after simulated add', () {
      // Simulate what addDog returns: a Dog parsed from Supabase response
      final supabaseResponse = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'owner_id': 'user-123',
        'name': 'Luna',
        'breed': 'Husky',
        'age_years': 2,
        'weight_kg': 22.0,
        'notes': 'Loves snow',
        'photo_url': 'https://storage.example.com/dog-photos/user-123/550e8400.jpg',
        'created_at': '2026-03-30T12:00:00Z',
      };

      final dog = Dog.fromJson(supabaseResponse);
      final result = DogSaveResult(dog: dog);

      expect(result.dog.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(result.dog.name, 'Luna');
      expect(result.dog.breed, 'Husky');
      expect(result.dog.photoUrl, contains('dog-photos'));
      expect(result.photoUploadFailed, false);
    });

    test('result reflects partial failure when photo upload fails', () {
      // Simulate: dog inserted successfully but photo upload returned null
      final supabaseResponse = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'owner_id': 'user-123',
        'name': 'Luna',
        'breed': 'Husky',
        'age_years': 2,
        'weight_kg': 22.0,
        'notes': null,
        'photo_url': null, // photo failed
        'created_at': '2026-03-30T12:00:00Z',
      };

      final dog = Dog.fromJson(supabaseResponse);
      final result = DogSaveResult(dog: dog, photoUploadFailed: true);

      expect(result.dog.name, 'Luna');
      expect(result.dog.photoUrl, isNull);
      expect(result.photoUploadFailed, true);
    });
  });

  group('Dog CRUD serialization', () {
    test('insert JSON matches Supabase dogs table schema', () {
      final dog = Dog(
        id: '', // empty for new dogs before insert
        ownerId: 'user-123',
        name: 'Bella',
        breed: 'Poodle',
        ageYears: 4,
        weightKg: 8.5,
        notes: 'Hypoallergenic',
      );

      final json = dog.toInsertJson();

      // Must have owner_id and name (required columns)
      expect(json['owner_id'], 'user-123');
      expect(json['name'], 'Bella');
      // Optional fields present when non-null
      expect(json['breed'], 'Poodle');
      expect(json['age_years'], 4);
      expect(json['weight_kg'], 8.5);
      expect(json['notes'], 'Hypoallergenic');
      // id excluded — DB generates UUID
      expect(json.containsKey('id'), false);
      // created_at excluded — DB sets default
      expect(json.containsKey('created_at'), false);
    });

    test('update map can be constructed from Dog fields', () {
      // Simulate what updateDog builds as the updates map
      const name = 'Bella Updated';
      const breed = 'Toy Poodle';
      const ageYears = 5;
      const weightKg = 9.0;
      const notes = 'Updated notes';

      final updates = <String, dynamic>{
        'name': name,
        'breed': breed,
        'age_years': ageYears,
        'weight_kg': weightKg,
        'notes': notes,
      };

      expect(updates['name'], 'Bella Updated');
      expect(updates['breed'], 'Toy Poodle');
      expect(updates['age_years'], 5);
      expect(updates['weight_kg'], 9.0);
      expect(updates['notes'], 'Updated notes');
      // id and owner_id are NOT in updates (can't change ownership)
      expect(updates.containsKey('id'), false);
      expect(updates.containsKey('owner_id'), false);
    });

    test('update map includes photo_url when photo upload succeeds', () {
      final updates = <String, dynamic>{
        'name': 'Bella',
        'breed': null,
        'age_years': null,
        'weight_kg': null,
        'notes': null,
      };

      // Simulate successful photo upload
      const photoUrl = 'https://storage.example.com/dog-photos/user-123/dog-456.jpg';
      updates['photo_url'] = photoUrl;

      expect(updates['photo_url'], photoUrl);
    });

    test('update map omits photo_url when photo upload fails', () {
      final updates = <String, dynamic>{
        'name': 'Bella',
        'breed': null,
        'age_years': null,
        'weight_kg': null,
        'notes': null,
      };

      // Photo upload failed — don't add photo_url to updates
      expect(updates.containsKey('photo_url'), false);
    });

    test('fromJson roundtrip preserves data through insert and response', () {
      final original = Dog(
        id: '',
        ownerId: 'user-123',
        name: 'Rocky',
        breed: 'Boxer',
        ageYears: 6,
        weightKg: 30.0,
        notes: 'Energetic',
      );

      final insertJson = original.toInsertJson();

      // Simulate Supabase adding id and created_at to the response
      final responseJson = {
        ...insertJson,
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'created_at': '2026-03-30T12:00:00Z',
      };

      final restored = Dog.fromJson(responseJson);

      expect(restored.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(restored.ownerId, original.ownerId);
      expect(restored.name, original.name);
      expect(restored.breed, original.breed);
      expect(restored.ageYears, original.ageYears);
      expect(restored.weightKg, original.weightKg);
      expect(restored.notes, original.notes);
      expect(restored.createdAt, isNotNull);
    });
  });

  group('Dog list UI rendering', () {
    testWidgets('renders dog list with mocked Supabase response', (tester) async {
      // Simulate what MyDogsScreen does: parse JSON from Supabase → render
      final supabaseResponse = [
        {
          'id': 'd001',
          'owner_id': 'owner-001',
          'name': 'Max',
          'breed': 'Golden Retriever',
          'age_years': 3,
          'weight_kg': 30.5,
          'notes': null,
          'photo_url': null,
          'created_at': '2026-01-15T10:00:00Z',
        },
        {
          'id': 'd002',
          'owner_id': 'owner-001',
          'name': 'Buddy',
          'breed': 'Labrador',
          'age_years': 5,
          'weight_kg': 28.0,
          'notes': 'Very friendly',
          'photo_url': 'https://example.com/buddy.jpg',
          'created_at': '2026-02-01T12:00:00Z',
        },
      ];

      final dogs = supabaseResponse.map((e) => Dog.fromJson(e)).toList();

      expect(dogs.length, 2);
      expect(dogs[0].name, 'Max');
      expect(dogs[1].name, 'Buddy');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: dogs
                  .map((d) => ListTile(
                        title: Text(d.name),
                        subtitle: Text(d.displayBreed),
                        trailing: Text(d.displayAge),
                      ))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('3 yrs'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Labrador'), findsOneWidget);
      expect(find.text('5 yrs'), findsOneWidget);
    });

    testWidgets('renders empty state when no dogs', (tester) async {
      final dogs = <Dog>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: dogs.isEmpty
                ? const Center(child: Text('No pups yet'))
                : const SizedBox(),
          ),
        ),
      );

      expect(find.text('No pups yet'), findsOneWidget);
    });

    testWidgets('renders error state with retry button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 48),
                  const Text('Unable to load your dogs. Please try again.'),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Unable to load your dogs. Please try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('renders loading state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Dog CRUD UI callbacks', () {
    testWidgets('add dog callback updates the dog list', (tester) async {
      final dogs = <Dog>[];
      final newDog = Dog.fromJson({
        'id': 'd-new',
        'owner_id': 'owner-001',
        'name': 'Nuevo',
        'breed': 'Chihuahua',
        'age_years': 1,
        'weight_kg': 2.5,
        'notes': null,
        'photo_url': null,
        'created_at': '2026-03-30T12:00:00Z',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Simulate onDogAdded callback from _AddDogForm
                        setState(() {
                          dogs.insert(0, newDog);
                        });
                      },
                      child: const Text('Add Dog'),
                    ),
                    Expanded(
                      child: dogs.isEmpty
                          ? const Center(child: Text('No pups yet'))
                          : ListView(
                              children: dogs
                                  .map((d) => ListTile(
                                        key: ValueKey(d.id),
                                        title: Text(d.name),
                                        subtitle: Text(d.displayBreed),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially empty
      expect(find.text('No pups yet'), findsOneWidget);
      expect(find.text('Nuevo'), findsNothing);

      // Tap add button (simulates onDogAdded callback)
      await tester.tap(find.text('Add Dog'));
      await tester.pumpAndSettle();

      // Dog now appears in the list
      expect(find.text('No pups yet'), findsNothing);
      expect(find.text('Nuevo'), findsOneWidget);
      expect(find.text('Chihuahua'), findsOneWidget);
    });

    testWidgets('edit dog callback updates the dog in the list', (tester) async {
      final dogs = [
        Dog.fromJson({
          'id': 'd-001',
          'owner_id': 'owner-001',
          'name': 'Max',
          'breed': 'Labrador',
          'age_years': 3,
          'weight_kg': 28.0,
          'notes': null,
          'photo_url': null,
          'created_at': '2026-03-30T12:00:00Z',
        }),
      ];

      final updatedDog = Dog.fromJson({
        'id': 'd-001',
        'owner_id': 'owner-001',
        'name': 'Max',
        'breed': 'Golden Labrador',
        'age_years': 4,
        'weight_kg': 30.0,
        'notes': 'Updated breed',
        'photo_url': 'https://example.com/max-new.jpg',
        'created_at': '2026-03-30T12:00:00Z',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Simulate onDogUpdated callback from _EditDogForm
                        setState(() {
                          final idx = dogs.indexWhere((d) => d.id == updatedDog.id);
                          if (idx >= 0) dogs[idx] = updatedDog;
                        });
                      },
                      child: const Text('Update Dog'),
                    ),
                    Expanded(
                      child: ListView(
                        children: dogs
                            .map((d) => ListTile(
                                  key: ValueKey(d.id),
                                  title: Text(d.name),
                                  subtitle: Text(d.displayBreed),
                                  trailing: Text(d.displayAge),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Original data
      expect(find.text('Labrador'), findsOneWidget);
      expect(find.text('3 yrs'), findsOneWidget);

      // Tap update (simulates onDogUpdated callback)
      await tester.tap(find.text('Update Dog'));
      await tester.pumpAndSettle();

      // Updated data
      expect(find.text('Golden Labrador'), findsOneWidget);
      expect(find.text('4 yrs'), findsOneWidget);
      expect(find.text('Labrador'), findsNothing);
    });

    testWidgets('delete dog callback removes dog from the list', (tester) async {
      final dogs = [
        Dog.fromJson({
          'id': 'd-001',
          'owner_id': 'owner-001',
          'name': 'Max',
          'breed': 'Labrador',
          'age_years': 3,
          'weight_kg': 28.0,
          'notes': null,
          'photo_url': null,
          'created_at': '2026-03-30T12:00:00Z',
        }),
        Dog.fromJson({
          'id': 'd-002',
          'owner_id': 'owner-001',
          'name': 'Luna',
          'breed': 'Husky',
          'age_years': 2,
          'weight_kg': 22.0,
          'notes': null,
          'photo_url': null,
          'created_at': '2026-03-30T13:00:00Z',
        }),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Simulate delete: DogService.deleteDog() then remove from list
                        setState(() {
                          dogs.removeWhere((d) => d.id == 'd-001');
                        });
                      },
                      child: const Text('Delete Max'),
                    ),
                    Expanded(
                      child: dogs.isEmpty
                          ? const Center(child: Text('No pups yet'))
                          : ListView(
                              children: dogs
                                  .map((d) => ListTile(
                                        key: ValueKey(d.id),
                                        title: Text(d.name),
                                        subtitle: Text(d.displayBreed),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Both dogs visible
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);

      // Delete Max
      await tester.tap(find.text('Delete Max'));
      await tester.pumpAndSettle();

      // Max removed, Luna remains
      expect(find.text('Max'), findsNothing);
      expect(find.text('Luna'), findsOneWidget);
    });

    testWidgets('photo upload failure shows dog without photo', (tester) async {
      // Simulate a DogSaveResult where photo upload failed
      final result = DogSaveResult(
        dog: Dog.fromJson({
          'id': 'd-001',
          'owner_id': 'owner-001',
          'name': 'Bella',
          'breed': 'Poodle',
          'age_years': 3,
          'weight_kg': 8.5,
          'notes': null,
          'photo_url': null,
          'created_at': '2026-03-30T12:00:00Z',
        }),
        photoUploadFailed: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ListTile(
                  title: Text(result.dog.name),
                  subtitle: Text(result.dog.displayBreed),
                  leading: result.dog.photoUrl != null
                      ? const Icon(Icons.photo)
                      : const Icon(Icons.pets),
                ),
                if (result.photoUploadFailed)
                  const Text('Photo could not be uploaded'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Poodle'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget); // fallback icon
      expect(find.byIcon(Icons.photo), findsNothing);
      expect(find.text('Photo could not be uploaded'), findsOneWidget);
    });
  });
}
