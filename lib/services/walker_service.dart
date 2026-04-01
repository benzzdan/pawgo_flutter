import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';

class WalkerService {
  static final _supabase = Supabase.instance.client;
  static const _tag = 'WalkerService';

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  /// Fetch all enabled walkers with their user profile info.
  static Future<List<Walker>> fetchWalkers() async {
    try {
      _log('fetchWalkers: fetching enabled walkers');
      final data = await _supabase
          .from('walkers')
          .select('*, users(full_name, avatar_url)')
          .eq('is_enabled', true)
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
