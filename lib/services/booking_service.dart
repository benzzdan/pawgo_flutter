import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';

class BookingService {
  static final _supabase = Supabase.instance.client;
  static const _tag = 'BookingService';

  static String get _userId => _supabase.auth.currentUser!.id;

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  /// Fetch all bookings for the authenticated user (as owner).
  /// Joins walker → users for walker name/avatar, and dogs for dog name.
  static Future<List<Booking>> fetchBookings() async {
    try {
      _log('fetchBookings: fetching for user=$_userId');
      final data = await _supabase
          .from('bookings')
          .select(
              '*, walkers(id, users(full_name, avatar_url)), dogs(name)')
          .eq('owner_id', _userId)
          .order('scheduled_at', ascending: false);
      final bookings =
          (data as List).map((e) => Booking.fromJson(e)).toList();
      _log('fetchBookings: got ${bookings.length} bookings');
      return bookings;
    } catch (e, st) {
      _log('fetchBookings: ERROR $e\n$st');
      rethrow;
    }
  }

  /// Fetch bookings for the authenticated user as a walker.
  static Future<List<Booking>> fetchWalkerBookings() async {
    try {
      _log('fetchWalkerBookings: fetching for walker user=$_userId');
      // Find the walker record for this user first
      final walkerData = await _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', _userId)
          .maybeSingle();

      if (walkerData == null) {
        _log('fetchWalkerBookings: no walker profile found');
        return [];
      }

      final walkerId = walkerData['id'] as String;
      final data = await _supabase
          .from('bookings')
          .select(
              '*, walkers(id, users(full_name, avatar_url)), dogs(name)')
          .eq('walker_id', walkerId)
          .order('scheduled_at', ascending: false);
      final bookings =
          (data as List).map((e) => Booking.fromJson(e)).toList();
      _log('fetchWalkerBookings: got ${bookings.length} bookings');
      return bookings;
    } catch (e, st) {
      _log('fetchWalkerBookings: ERROR $e\n$st');
      rethrow;
    }
  }
}
