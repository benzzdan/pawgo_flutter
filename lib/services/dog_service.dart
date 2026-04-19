import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';

/// Result of a dog save operation that may include a partial failure (e.g. photo upload).
class DogSaveResult {
  final Dog dog;
  final bool photoUploadFailed;

  const DogSaveResult({required this.dog, this.photoUploadFailed = false});
}

class DogService {
  static final _supabase = Supabase.instance.client;
  static const _tag = 'DogService';

  static String get _userId => _supabase.auth.currentUser!.id;

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  /// Fetch all dogs for the current user.
  static Future<List<Dog>> fetchDogs() async {
    try {
      _log('fetchDogs: fetching for user=$_userId');
      final data = await _supabase
          .from('dogs')
          .select()
          .eq('owner_id', _userId)
          .order('created_at', ascending: false);
      _log('fetchDogs: got ${(data as List).length} dogs');
      return data.map((e) => Dog.fromJson(e)).toList();
    } catch (e, st) {
      _log('fetchDogs: ERROR $e\n$st');
      rethrow;
    }
  }

  /// Upload a photo to Supabase Storage and return its public URL.
  static Future<String?> uploadPhoto(String dogId, Uint8List bytes) async {
    final filePath = '$_userId/$dogId.jpg';
    try {
      final sizeKB = (bytes.length / 1024).toStringAsFixed(1);
      _log('uploadPhoto: uploading ${sizeKB}KB to dog-photos/$filePath');

      await _supabase.storage.from('dog-photos').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final publicUrl =
          _supabase.storage.from('dog-photos').getPublicUrl(filePath);
      _log('uploadPhoto: success → $publicUrl');
      return publicUrl;
    } on StorageException catch (e, st) {
      _log('uploadPhoto: StorageException statusCode=${e.statusCode} message=${e.message} error=${e.error}\n$st');
      return null;
    } catch (e, st) {
      _log('uploadPhoto: ERROR ${e.runtimeType}: $e\n$st');
      return null;
    }
  }

  /// Insert a new dog and return it.
  static Future<DogSaveResult> addDog({
    required String name,
    String? breed,
    int? ageYears,
    double? weightKg,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    try {
      _log('addDog: name=$name breed=$breed');
      final dog = Dog(
        id: '',
        ownerId: _userId,
        name: name,
        breed: breed,
        ageYears: ageYears,
        weightKg: weightKg,
        notes: notes,
      );
      final data = await _supabase
          .from('dogs')
          .insert(dog.toInsertJson())
          .select()
          .single();
      var created = Dog.fromJson(data);
      _log('addDog: inserted id=${created.id}');

      // Upload photo after insert so we have the real dog ID
      var photoFailed = false;
      if (photoBytes != null) {
        final photoUrl = await uploadPhoto(created.id, photoBytes);
        if (photoUrl != null) {
          await _supabase
              .from('dogs')
              .update({'photo_url': photoUrl})
              .eq('id', created.id);
          created = Dog(
            id: created.id,
            ownerId: created.ownerId,
            name: created.name,
            breed: created.breed,
            ageYears: created.ageYears,
            weightKg: created.weightKg,
            notes: created.notes,
            photoUrl: photoUrl,
            createdAt: created.createdAt,
          );
          _log('addDog: photo_url updated');
        } else {
          photoFailed = true;
          _log('addDog: photo upload failed, dog saved without photo');
        }
      }

      return DogSaveResult(dog: created, photoUploadFailed: photoFailed);
    } catch (e, st) {
      _log('addDog: ERROR $e\n$st');
      rethrow;
    }
  }

  /// Update an existing dog and return it.
  static Future<DogSaveResult> updateDog({
    required String dogId,
    required String name,
    String? breed,
    int? ageYears,
    double? weightKg,
    String? notes,
    Uint8List? photoBytes,
  }) async {
    try {
      _log('updateDog: id=$dogId name=$name');
      final updates = <String, dynamic>{
        'name': name,
        'breed': breed,
        'age_years': ageYears,
        'weight_kg': weightKg,
        'notes': notes,
      };

      var photoFailed = false;
      if (photoBytes != null) {
        final photoUrl = await uploadPhoto(dogId, photoBytes);
        if (photoUrl != null) {
          updates['photo_url'] = photoUrl;
        } else {
          photoFailed = true;
          _log('updateDog: photo upload failed, updating other fields only');
        }
      }

      final data = await _supabase
          .from('dogs')
          .update(updates)
          .eq('id', dogId)
          .select()
          .single();
      _log('updateDog: success');
      return DogSaveResult(dog: Dog.fromJson(data), photoUploadFailed: photoFailed);
    } catch (e, st) {
      _log('updateDog: ERROR $e\n$st');
      rethrow;
    }
  }

  /// Delete a dog by id.
  static Future<void> deleteDog(String dogId) async {
    try {
      _log('deleteDog: id=$dogId');
      await _supabase.from('dogs').delete().eq('id', dogId);
      _log('deleteDog: success');
    } catch (e, st) {
      _log('deleteDog: ERROR $e\n$st');
      rethrow;
    }
  }
}
