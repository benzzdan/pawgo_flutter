import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';

class EarningsService {
  static final _supabase = Supabase.instance.client;
  static const _tag = 'EarningsService';

  static String get _userId => _supabase.auth.currentUser!.id;

  static void _log(String message) {
    developer.log(message, name: _tag);
  }

  /// Fetch all payments for the authenticated walker's bookings.
  /// Joins through bookings to get dog name, owner name, and commission.
  static Future<List<Payment>> fetchWalkerPayments() async {
    try {
      _log('fetchWalkerPayments: fetching for user=$_userId');

      // Find the walker record for this user
      final walkerData = await _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', _userId)
          .maybeSingle();

      if (walkerData == null) {
        _log('fetchWalkerPayments: no walker profile found');
        return [];
      }

      final walkerId = walkerData['id'] as String;

      // Query payments joined with bookings (filtered by walker_id)
      final data = await _supabase
          .from('payments')
          .select(
              '*, bookings!inner(scheduled_at, commission_mxn, walker_id, dogs(name), users!bookings_owner_id_fkey(full_name))')
          .eq('bookings.walker_id', walkerId)
          .order('created_at', ascending: false);

      final payments =
          (data as List).map((e) => Payment.fromJson(e)).toList();
      _log('fetchWalkerPayments: got ${payments.length} payments');
      return payments;
    } catch (e, st) {
      _log('fetchWalkerPayments: ERROR $e\n$st');
      rethrow;
    }
  }
}
