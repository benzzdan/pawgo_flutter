import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/services/saved_address_service.dart';

/// Mock Supabase client for testing SavedAddressService.
class MockSupabaseClient implements SavedAddressClient {
  final List<Map<String, dynamic>> _addresses = [];
  String? lastTable;
  Map<String, dynamic>? lastUpsertData;
  String? lastDeleteId;

  @override
  Future<List<Map<String, dynamic>>> fetchAddresses(String userId) async {
    return _addresses.where((a) => a['user_id'] == userId).toList();
  }

  @override
  Future<Map<String, dynamic>> upsertAddress(
      Map<String, dynamic> data) async {
    lastUpsertData = data;
    final id = data['id'] ?? 'generated-id';
    final entry = {...data, 'id': id};
    final idx = _addresses.indexWhere((a) => a['id'] == id);
    if (idx >= 0) {
      _addresses[idx] = entry;
    } else {
      _addresses.add(entry);
    }
    return entry;
  }

  @override
  Future<void> deleteAddress(String id) async {
    lastDeleteId = id;
    _addresses.removeWhere((a) => a['id'] == id);
  }

  @override
  Future<void> clearDefault(String userId) async {
    for (final a in _addresses) {
      if (a['user_id'] == userId) {
        a['is_default'] = false;
      }
    }
  }

  @override
  Future<void> setDefault(String id) async {
    for (final a in _addresses) {
      if (a['id'] == id) {
        a['is_default'] = true;
      }
    }
  }

  void seedAddresses(List<Map<String, dynamic>> addresses) {
    _addresses.clear();
    _addresses.addAll(addresses);
  }
}

void main() {
  group('SavedAddressService', () {
    late MockSupabaseClient mockClient;
    late SavedAddressService service;

    setUp(() {
      mockClient = MockSupabaseClient();
      service = SavedAddressService(client: mockClient);
    });

    test('fetchAddresses returns parsed SavedAddress list', () async {
      mockClient.seedAddresses([
        {
          'id': 'addr-1',
          'user_id': 'user-1',
          'label': 'Home',
          'street_address': '123 Main St',
          'city': 'NYC',
          'state': 'NY',
          'zip_code': '10001',
          'latitude': 40.7,
          'longitude': -74.0,
          'is_default': true,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);

      final addresses = await service.fetchAddresses('user-1');

      expect(addresses, hasLength(1));
      expect(addresses[0].label, 'Home');
      expect(addresses[0].streetAddress, '123 Main St');
      expect(addresses[0].isDefault, isTrue);
      expect(addresses[0].latitude, 40.7);
    });

    test('createAddress upserts with correct data', () async {
      await service.createAddress(
        userId: 'user-1',
        label: 'Work',
        streetAddress: '456 Office Blvd',
        city: 'NYC',
        state: 'NY',
        zipCode: '10002',
        latitude: 40.8,
        longitude: -73.9,
      );

      expect(mockClient.lastUpsertData!['label'], 'Work');
      expect(mockClient.lastUpsertData!['street_address'], '456 Office Blvd');
      expect(mockClient.lastUpsertData!['user_id'], 'user-1');
    });

    test('deleteAddress calls delete with correct id', () async {
      await service.deleteAddress('addr-1');
      expect(mockClient.lastDeleteId, 'addr-1');
    });

    test('setDefault clears existing defaults then sets new', () async {
      mockClient.seedAddresses([
        {
          'id': 'addr-1',
          'user_id': 'user-1',
          'label': 'Home',
          'street_address': '123 Main',
          'is_default': true,
        },
        {
          'id': 'addr-2',
          'user_id': 'user-1',
          'label': 'Work',
          'street_address': '456 Office',
          'is_default': false,
        },
      ]);

      await service.setDefault('addr-2', 'user-1');

      final addresses = await service.fetchAddresses('user-1');
      final home = addresses.firstWhere((a) => a.id == 'addr-1');
      final work = addresses.firstWhere((a) => a.id == 'addr-2');
      expect(home.isDefault, isFalse);
      expect(work.isDefault, isTrue);
    });
  });

  group('SavedAddress model', () {
    test('fromJson parses database row correctly', () {
      final addr = SavedAddress.fromJson({
        'id': 'addr-1',
        'user_id': 'user-1',
        'label': 'Home',
        'street_address': '123 Main St',
        'city': 'NYC',
        'state': 'NY',
        'zip_code': '10001',
        'latitude': 40.7128,
        'longitude': -74.0060,
        'is_default': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(addr.id, 'addr-1');
      expect(addr.userId, 'user-1');
      expect(addr.label, 'Home');
      expect(addr.streetAddress, '123 Main St');
      expect(addr.city, 'NYC');
      expect(addr.isDefault, isTrue);
    });

    test('displayAddress formats city, state, zip', () {
      final addr = SavedAddress.fromJson({
        'id': 'a',
        'user_id': 'u',
        'label': 'Home',
        'street_address': '123 Main St',
        'city': 'NYC',
        'state': 'NY',
        'zip_code': '10001',
        'is_default': false,
      });

      expect(addr.displayAddress, '123 Main St, NYC, NY 10001');
    });
  });
}
