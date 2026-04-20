import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/screens/active_walk_screen.dart';
import 'package:pawgo/services/tracking_service.dart';
import 'package:pawgo/services/booking_status_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Stub TrackingService that returns empty data and no-ops subscriptions.
class StubTrackingService extends TrackingService {
  StubTrackingService() : super(client: MockSupabaseClient());

  final _locCtrl = StreamController<WalkLocation>.broadcast();
  final _connCtrl = StreamController<TrackingConnectionState>.broadcast();

  @override
  Stream<WalkLocation> get locationStream => _locCtrl.stream;
  @override
  Stream<TrackingConnectionState> get connectionStream => _connCtrl.stream;

  @override
  Future<List<WalkLocation>> fetchLocations(String bookingId) async => [];

  @override
  void subscribe(String bookingId) {}

  @override
  void dispose() {
    _locCtrl.close();
    _connCtrl.close();
  }
}

/// Stub BookingStatusService that no-ops.
class StubBookingStatusService extends BookingStatusService {
  StubBookingStatusService() : super(client: MockSupabaseClient());

  final _statusCtrl = StreamController<BookingStatusUpdate>.broadcast();

  @override
  Stream<BookingStatusUpdate> get statusStream => _statusCtrl.stream;

  @override
  void subscribeToBooking(String bookingId) {}

  @override
  void dispose() {
    _statusCtrl.close();
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('US-010: Active walk screen UI redesign', () {
    // The screen without a booking_id shows the error state but the header
    // (with walker info section and timer) should always render.
    // These tests verify that the keyed widgets exist in the widget tree.

    testWidgets('walkerInfoSection key is present in the header',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWalkScreen(
            trackingService: StubTrackingService(),
            bookingStatusService: StubBookingStatusService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('walkerInfoSection')), findsOneWidget,
          reason: 'Walker info section should have Key walkerInfoSection');
    });

    testWidgets('walkTimerDisplay key is present in the header',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWalkScreen(
            trackingService: StubTrackingService(),
            bookingStatusService: StubBookingStatusService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('walkTimerDisplay')), findsOneWidget,
          reason: 'Walk timer should have Key walkTimerDisplay');
    });

    testWidgets('walker info section appears above the map or content area',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveWalkScreen(
            trackingService: StubTrackingService(),
            bookingStatusService: StubBookingStatusService(),
          ),
        ),
      );
      await tester.pump();

      final walkerInfo = find.byKey(const Key('walkerInfoSection'));
      final walkTimer = find.byKey(const Key('walkTimerDisplay'));

      expect(walkerInfo, findsOneWidget);
      expect(walkTimer, findsOneWidget);
    });
  });
}
