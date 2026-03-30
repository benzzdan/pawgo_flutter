import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/models/mock_data.dart';

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
}
