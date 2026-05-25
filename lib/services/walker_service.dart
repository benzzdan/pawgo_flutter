import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/screens/find_screen.dart' show AdvancedFilters;

class WalkerService {
  static final _supabase = Supabase.instance.client;
  static const _tag = 'WalkerService';

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  /// Build the param map sent to the `nearby_walkers` RPC.
  ///
  /// Range bounds from [filters] are forwarded as their snake_case RPC
  /// param names. Bounds that are null on the model are OMITTED from the
  /// map entirely so the RPC's defaults kick in (NULL → no constraint on
  /// that side). minExperience / backgroundChecked / onlyShowInRange are
  /// NOT forwarded — those are filters the RPC does not support yet and
  /// are applied client-side (see [_applyAdvancedFilters] in find_screen).
  ///
  /// Exposed as a public helper so it can be unit-tested without touching
  /// Supabase initialization.
  static Map<String, dynamic> buildNearbyWalkersParams({
    required double latitude,
    required double longitude,
    AdvancedFilters? filters,
  }) {
    final params = <String, dynamic>{
      'search_lat': latitude,
      'search_lng': longitude,
    };
    if (filters == null) return params;

    if (filters.minDistanceKm != null) {
      params['min_distance_km'] = filters.minDistanceKm;
    }
    if (filters.maxDistanceKm != null) {
      params['max_distance_km'] = filters.maxDistanceKm;
    }
    if (filters.minRate != null) {
      params['min_price_mxn'] = filters.minRate;
    }
    if (filters.maxRate != null) {
      params['max_price_mxn'] = filters.maxRate;
    }
    return params;
  }

  /// Fetch enabled + verified walkers from the backend.
  ///
  /// When [latitude] and [longitude] are provided, walkers are sorted by
  /// proximity using the PostGIS-backed `nearby_walkers` RPC (migration
  /// 042). Optional [filters] forward their range bounds to the RPC so
  /// the server can do distance + price filtering — the client only
  /// applies the filters the RPC doesn't support (minExperience,
  /// backgroundChecked, onlyShowInRange dropping NULL-distance walkers).
  ///
  /// When lat/lng are omitted, falls back to default avg_rating sort
  /// (no proximity filtering possible without an origin point).
  static Future<List<Walker>> fetchWalkers({
    double? latitude,
    double? longitude,
    AdvancedFilters? filters,
  }) async {
    try {
      if (latitude != null && longitude != null) {
        final params = buildNearbyWalkersParams(
          latitude: latitude,
          longitude: longitude,
          filters: filters,
        );
        _log(
            'fetchWalkers: proximity search lat=$latitude lng=$longitude params=$params');
        final data = await _supabase.rpc('nearby_walkers', params: params);
        final walkers =
            (data as List).map((e) => Walker.fromRpc(e)).toList();
        _log('fetchWalkers: got ${walkers.length} walkers (proximity)');
        return walkers;
      }

      _log('fetchWalkers: fetching enabled + verified walkers');
      final data = await _supabase
          .from('walkers')
          .select('*, users(full_name, avatar_url)')
          .eq('is_enabled', true)
          .eq('verification_status', 'verified')
          .order('avg_rating', ascending: false);
      final walkers = (data as List).map((e) => Walker.fromJson(e)).toList();
      _log('fetchWalkers: got ${walkers.length} walkers');
      return walkers;
    } catch (e, st) {
      _log('fetchWalkers: ERROR $e\n$st');
      rethrow;
    }
  }

  /// Fetch a single walker by ID with user profile info.
  static Future<Walker?> fetchWalkerById(String walkerId) async {
    try {
      _log('fetchWalkerById: id=$walkerId');
      final data = await _supabase
          .from('walkers')
          .select('*, users(full_name, avatar_url)')
          .eq('id', walkerId)
          .maybeSingle();
      if (data == null) {
        _log('fetchWalkerById: not found');
        return null;
      }
      _log('fetchWalkerById: found');
      return Walker.fromJson(data);
    } catch (e, st) {
      _log('fetchWalkerById: ERROR $e\n$st');
      rethrow;
    }
  }
}
