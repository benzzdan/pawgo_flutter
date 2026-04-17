import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

class SavedAddress {
  final String id;
  final String userId;
  final String label;
  final String streetAddress;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.streetAddress,
    this.city,
    this.state,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String,
      streetAddress: json['street_address'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  String get displayAddress {
    final parts = [streetAddress];
    if (city != null) parts.add(city!);
    if (state != null && zipCode != null) {
      parts.add('$state $zipCode');
    } else if (state != null) {
      parts.add(state!);
    } else if (zipCode != null) {
      parts.add(zipCode!);
    }
    return parts.join(', ');
  }

  String get iconType {
    final lower = label.toLowerCase();
    if (lower.contains('home')) return 'home';
    if (lower.contains('work') || lower.contains('office')) return 'work';
    return 'other';
  }
}

/// Abstract client for testability — swap with mock in tests.
abstract class SavedAddressClient {
  Future<List<Map<String, dynamic>>> fetchAddresses(String userId);
  Future<Map<String, dynamic>> upsertAddress(Map<String, dynamic> data);
  Future<void> deleteAddress(String id);
  Future<void> clearDefault(String userId);
  Future<void> setDefault(String id);
}

class _SupabaseAddressClient implements SavedAddressClient {
  final SupabaseClient _supabase;
  _SupabaseAddressClient(this._supabase);

  @override
  Future<List<Map<String, dynamic>>> fetchAddresses(String userId) async {
    final data = await _supabase
        .from('saved_addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Future<Map<String, dynamic>> upsertAddress(
      Map<String, dynamic> data) async {
    final result = await _supabase
        .from('saved_addresses')
        .upsert(data)
        .select()
        .single();
    return result;
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _supabase.from('saved_addresses').delete().eq('id', id);
  }

  @override
  Future<void> clearDefault(String userId) async {
    await _supabase
        .from('saved_addresses')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
  }

  @override
  Future<void> setDefault(String id) async {
    await _supabase
        .from('saved_addresses')
        .update({'is_default': true})
        .eq('id', id);
  }
}

class SavedAddressService {
  static const _tag = 'SavedAddressService';
  final SavedAddressClient _client;

  SavedAddressService({SavedAddressClient? client})
      : _client = client ??
            _SupabaseAddressClient(Supabase.instance.client);

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  Future<List<SavedAddress>> fetchAddresses(String userId) async {
    try {
      _log('fetchAddresses: userId=$userId');
      final data = await _client.fetchAddresses(userId);
      return data.map((e) => SavedAddress.fromJson(e)).toList();
    } catch (e, st) {
      _log('fetchAddresses: ERROR $e\n$st');
      rethrow;
    }
  }

  Future<SavedAddress> createAddress({
    required String userId,
    required String label,
    required String streetAddress,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      _log('createAddress: label=$label');
      final data = await _client.upsertAddress({
        'user_id': userId,
        'label': label,
        'street_address': streetAddress,
        'city': city,
        'state': state,
        'zip_code': zipCode,
        'latitude': latitude,
        'longitude': longitude,
      });
      return SavedAddress.fromJson(data);
    } catch (e, st) {
      _log('createAddress: ERROR $e\n$st');
      rethrow;
    }
  }

  Future<SavedAddress> updateAddress({
    required String id,
    required String label,
    required String streetAddress,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      _log('updateAddress: id=$id');
      final data = await _client.upsertAddress({
        'id': id,
        'label': label,
        'street_address': streetAddress,
        'city': city,
        'state': state,
        'zip_code': zipCode,
        'latitude': latitude,
        'longitude': longitude,
      });
      return SavedAddress.fromJson(data);
    } catch (e, st) {
      _log('updateAddress: ERROR $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      _log('deleteAddress: id=$id');
      await _client.deleteAddress(id);
    } catch (e, st) {
      _log('deleteAddress: ERROR $e\n$st');
      rethrow;
    }
  }

  Future<void> setDefault(String id, String userId) async {
    try {
      _log('setDefault: id=$id');
      await _client.clearDefault(userId);
      await _client.setDefault(id);
    } catch (e, st) {
      _log('setDefault: ERROR $e\n$st');
      rethrow;
    }
  }
}
