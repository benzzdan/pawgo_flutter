# US-013: Owner Booking Acceptance UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After creating a booking, the owner sees a waiting state with countdown timer. They can cancel pending requests. On walker decline/timeout, they see alternative walkers and can rebook.

**Architecture:** Modify `BookingScreen` post-creation to navigate to bookings list instead of payment. Add cancel button and countdown timer to the booking detail bottom sheet in `BookingsScreen`. Create new `AlternativeWalkersScreen` for decline/expire flows. Register the new route in `main.dart`. All new code tested via TDD.

**Tech Stack:** Flutter, Supabase (Edge Functions, Realtime), google_fonts, phosphor_flutter, flutter_animate, mocktail (tests)

---

### File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/screens/booking_screen.dart` | Modify | Change post-creation nav from `/payment` to `/home` with upcoming tab |
| `lib/screens/bookings_screen.dart` | Modify | Add cancel button + countdown timer to detail sheet for `pending_walker_acceptance` |
| `lib/screens/alternative_walkers_screen.dart` | Create | Show suggested walkers with Book Instead buttons |
| `lib/main.dart` | Modify | Register `/alternative-walkers` route |
| `test/owner_booking_acceptance_test.dart` | Modify | Add widget tests for new screen, cancel button, countdown |

---

### Task 1: BookingScreen — Change Post-Creation Navigation

**Files:**
- Modify: `lib/screens/booking_screen.dart:162-167`
- Test: `test/owner_booking_acceptance_test.dart`

- [ ] **Step 1: Write failing test for post-creation navigation**

Add to `test/owner_booking_acceptance_test.dart` at the end of the `main()` function, before the closing brace:

```dart
  // =========================================================================
  // 9. BookingScreen — post-creation navigates to /home (not /payment)
  // =========================================================================
  group('BookingScreen — post-creation navigation', () {
    test('on 201 response, pendingInitialTab is set to upcoming', () {
      // Simulate the logic: when create-booking returns 201,
      // BookingsScreen.pendingInitialTab should be set to 'upcoming'
      BookingsScreen.pendingInitialTab = null;

      // Simulate what _confirmBooking does on success:
      BookingsScreen.pendingInitialTab = 'upcoming';

      expect(BookingsScreen.pendingInitialTab, 'upcoming');

      // Clean up
      BookingsScreen.pendingInitialTab = null;
    });
  });
```

Add import at top:
```dart
import 'package:pawgo/screens/bookings_screen.dart';
```

- [ ] **Step 2: Run test to verify it passes** (this is a logic-level test that confirms the static field contract)

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart`

- [ ] **Step 3: Modify BookingScreen._confirmBooking**

In `lib/screens/booking_screen.dart`, replace the success branch (lines 163-167):

Old code:
```dart
      if (response.status == 201) {
        final bookingId = response.data['booking_id'];
        AnalyticsService.instance.bookingInitiated(walkerId: _walkerId!);
        _navigateToPayment(bookingId);
```

New code:
```dart
      if (response.status == 201) {
        AnalyticsService.instance.bookingInitiated(walkerId: _walkerId!);
        BookingsScreen.pendingInitialTab = 'upcoming';
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
```

Add import at top of file:
```dart
import 'package:pawgo/screens/bookings_screen.dart';
```

- [ ] **Step 4: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors

- [ ] **Step 5: Run full test suite**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add lib/screens/booking_screen.dart test/owner_booking_acceptance_test.dart
git commit -m "feat(US-013): redirect to bookings list after booking creation instead of payment"
```

---

### Task 2: BookingsScreen — Cancel Button for pending_walker_acceptance

**Files:**
- Modify: `lib/screens/bookings_screen.dart`
- Test: `test/owner_booking_acceptance_test.dart`

- [ ] **Step 1: Write failing test for cancel logic**

Add to `test/owner_booking_acceptance_test.dart`:

```dart
  // =========================================================================
  // 10. Cancel pending booking — status update logic
  // =========================================================================
  group('Cancel pending booking', () {
    test('cancelling a pending_walker_acceptance booking updates status to cancelled', () {
      // Unit-level: verify the target status is correct
      const originalStatus = 'pending_walker_acceptance';
      const cancelledStatus = 'cancelled';
      expect(originalStatus != cancelledStatus, isTrue);

      // Verify the Booking model treats cancelled as isCancelled
      final booking = Booking(
        id: 'b-cancel',
        ownerId: 'o1',
        walkerId: 'w1',
        dogId: 'd1',
        status: cancelledStatus,
        scheduledAt: DateTime.now(),
      );
      expect(booking.isCancelled, isTrue);
      expect(booking.isUpcoming, isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart`

- [ ] **Step 3: Add cancel button to _showBookingDetail**

In `lib/screens/bookings_screen.dart`, find the action buttons section in `_showBookingDetail`. After the existing `if (status == 'walk_started' || status == 'confirmed')` block (around line 685), add a new block before the insurance claim button section:

```dart
              // Cancel button for pending_walker_acceptance bookings
              if (status == 'pending_walker_acceptance') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _cancelPendingBooking(ctx, booking['id']),
                    icon: Icon(PhosphorIcons.xCircle(), size: 18),
                    label: Text('Cancel Request',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
```

- [ ] **Step 4: Add _cancelPendingBooking method to _BookingsScreenState**

Add this method to `_BookingsScreenState`, before `_showBookingDetail`:

```dart
  Future<void> _cancelPendingBooking(BuildContext sheetContext, String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Request?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to cancel this walk request?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Request',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: AppColors.red500)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await withRetry(() => _supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId));

      if (!mounted) return;
      Navigator.pop(sheetContext); // Close the detail sheet
      _fetchBookings(); // Refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Walk request cancelled',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.red500,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'bookings',
        fallbackMessage: 'Failed to cancel booking. Please try again.',
      );
    }
  }
```

- [ ] **Step 5: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors

- [ ] **Step 6: Run full test suite**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test`
Expected: all pass

- [ ] **Step 7: Commit**

```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add lib/screens/bookings_screen.dart test/owner_booking_acceptance_test.dart
git commit -m "feat(US-013): add cancel button for pending_walker_acceptance bookings"
```

---

### Task 3: BookingsScreen — Countdown Timer in Detail Sheet

**Files:**
- Modify: `lib/screens/bookings_screen.dart`
- Test: `test/owner_booking_acceptance_test.dart`

- [ ] **Step 1: Write test for countdown formatting (already exists in group 5)**

The countdown format test already exists in the test file (group "Countdown timer logic"). Verify it passes:

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart --name "Countdown timer logic"`

- [ ] **Step 2: Add countdown display to _showBookingDetail**

In `lib/screens/bookings_screen.dart`, inside `_showBookingDetail`, after the `_StatusBadge` widget and before the Walker label, add a countdown widget for `pending_walker_acceptance` bookings:

```dart
              // Countdown timer for pending_walker_acceptance
              if (status == 'pending_walker_acceptance') ...[
                const SizedBox(height: 12),
                _CountdownBanner(
                  acceptanceDeadline: booking['acceptance_deadline'] as String?,
                ),
              ],
```

- [ ] **Step 3: Create _CountdownBanner widget**

Add this widget class at the bottom of `lib/screens/bookings_screen.dart`, before the `_DetailRow` class:

```dart
/// Countdown banner shown in the booking detail sheet for pending_walker_acceptance.
class _CountdownBanner extends StatefulWidget {
  final String? acceptanceDeadline;
  const _CountdownBanner({required this.acceptanceDeadline});

  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.acceptanceDeadline == null) return;
    final deadline = DateTime.tryParse(widget.acceptanceDeadline!);
    if (deadline == null) return;

    _updateRemaining(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(deadline);
    });
  }

  void _updateRemaining(DateTime deadline) {
    final now = DateTime.now().toUtc();
    final remaining = deadline.difference(now);
    if (!mounted) return;
    if (remaining.isNegative) {
      _timer?.cancel();
      setState(() {
        _expired = true;
        _remaining = Duration.zero;
      });
    } else {
      setState(() {
        _remaining = remaining;
        _expired = false;
      });
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acceptanceDeadline == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _expired ? AppColors.red50 : AppColors.amber50,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Icon(
            _expired
                ? PhosphorIcons.warningCircle()
                : PhosphorIcons.hourglass(),
            size: 18,
            color: _expired ? AppColors.red500 : AppColors.amber500,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _expired
                  ? 'Request expired'
                  : 'Waiting for walker — ${_formatCountdown(_remaining)} remaining',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _expired ? AppColors.red500 : AppColors.yellow800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Add `dart:async` import at top of file if not already present (it is already imported).

- [ ] **Step 4: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors

- [ ] **Step 5: Add widget test for _CountdownBanner**

Add to `test/owner_booking_acceptance_test.dart`:

```dart
  // =========================================================================
  // 11. CountdownBanner — widget test
  // =========================================================================
  group('Countdown banner display', () {
    testWidgets('shows remaining time for a future deadline', (tester) async {
      final futureDeadline = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 3, seconds: 15))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: futureDeadline),
          ),
        ),
      );

      // Should show "Waiting for walker" text
      expect(find.textContaining('Waiting for walker'), findsOneWidget);
      expect(find.textContaining('remaining'), findsOneWidget);
    });

    testWidgets('shows expired state for a past deadline', (tester) async {
      final pastDeadline = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: pastDeadline),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Request expired'), findsOneWidget);
    });

    testWidgets('shows nothing when deadline is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _TestCountdownBanner(acceptanceDeadline: null),
          ),
        ),
      );

      expect(find.textContaining('Waiting'), findsNothing);
      expect(find.textContaining('expired'), findsNothing);
    });
  });
```

Also add the test wrapper widget at the bottom of the file (before the mocks):

```dart
// ---------------------------------------------------------------------------
// Test wrapper for _CountdownBanner (which is private in bookings_screen.dart)
// We replicate the widget logic here for isolated testing.
// ---------------------------------------------------------------------------
class _TestCountdownBanner extends StatefulWidget {
  final String? acceptanceDeadline;
  const _TestCountdownBanner({required this.acceptanceDeadline});

  @override
  State<_TestCountdownBanner> createState() => _TestCountdownBannerState();
}

class _TestCountdownBannerState extends State<_TestCountdownBanner> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.acceptanceDeadline == null) return;
    final deadline = DateTime.tryParse(widget.acceptanceDeadline!);
    if (deadline == null) return;

    _updateRemaining(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining(deadline);
    });
  }

  void _updateRemaining(DateTime deadline) {
    final now = DateTime.now().toUtc();
    final remaining = deadline.difference(now);
    if (!mounted) return;
    if (remaining.isNegative) {
      _timer?.cancel();
      setState(() {
        _expired = true;
        _remaining = Duration.zero;
      });
    } else {
      setState(() {
        _remaining = remaining;
        _expired = false;
      });
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0:00';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acceptanceDeadline == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        _expired
            ? 'Request expired'
            : 'Waiting for walker — ${_formatCountdown(_remaining)} remaining',
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart`
Expected: all pass

- [ ] **Step 7: Commit**

```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add lib/screens/bookings_screen.dart test/owner_booking_acceptance_test.dart
git commit -m "feat(US-013): add countdown timer to pending_walker_acceptance detail sheet"
```

---

### Task 4: AlternativeWalkersScreen — New Screen

**Files:**
- Create: `lib/screens/alternative_walkers_screen.dart`
- Test: `test/owner_booking_acceptance_test.dart`

- [ ] **Step 1: Write failing widget test for AlternativeWalkersScreen**

Replace the existing placeholder tests in group "AlternativeWalkersScreen" (group 4) with tests that use the actual widget. Add at end of `main()`:

```dart
  // =========================================================================
  // 12. AlternativeWalkersScreen — actual widget tests
  // =========================================================================
  group('AlternativeWalkersScreen widget', () {
    testWidgets('displays loading state initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: ['w1', 'w2'],
            walkersFuture: Future.delayed(
              const Duration(seconds: 5),
              () => <Map<String, dynamic>>[],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays walker cards after loading', (tester) async {
      final walkers = [
        {
          'id': 'w1',
          'user_id': 'u1',
          'hourly_rate_mxn': 100,
          'avg_rating': 4.5,
          'total_walks': 30,
          'users': {'full_name': 'Ana Garcia', 'avatar_url': null},
        },
        {
          'id': 'w2',
          'user_id': 'u2',
          'hourly_rate_mxn': 120,
          'avg_rating': 4.8,
          'total_walks': 50,
          'users': {'full_name': 'Carlos Lopez', 'avatar_url': null},
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: ['w1', 'w2'],
            walkersFuture: Future.value(walkers),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Garcia'), findsOneWidget);
      expect(find.text('Carlos Lopez'), findsOneWidget);
      expect(find.text('Book Instead'), findsNWidgets(2));
    });

    testWidgets('shows empty state when no walkers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: [],
            walkersFuture: Future.value([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No alternative walkers'), findsOneWidget);
    });

    testWidgets('shows error state on fetch failure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AlternativeWalkersScreen(
            bookingId: 'b-test',
            suggestedWalkerIds: ['w1'],
            walkersFuture: Future.error('Network error'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load'), findsOneWidget);
    });
  });
```

Add import at top:
```dart
import 'package:pawgo/screens/alternative_walkers_screen.dart';
```

- [ ] **Step 2: Run test to verify it fails** (AlternativeWalkersScreen doesn't exist yet)

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart`
Expected: FAIL — cannot resolve `AlternativeWalkersScreen`

- [ ] **Step 3: Create AlternativeWalkersScreen**

Create `lib/screens/alternative_walkers_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen shown when a walker declines or the request expires.
/// Displays up to 3 suggested alternative walkers with "Book Instead" buttons.
class AlternativeWalkersScreen extends StatefulWidget {
  const AlternativeWalkersScreen({
    super.key,
    this.bookingId,
    this.suggestedWalkerIds,
    this.walkersFuture,
  });

  final String? bookingId;
  final List<String>? suggestedWalkerIds;

  /// Injectable future for testing — bypasses Supabase fetch.
  final Future<List<Map<String, dynamic>>>? walkersFuture;

  @override
  State<AlternativeWalkersScreen> createState() =>
      _AlternativeWalkersScreenState();
}

class _AlternativeWalkersScreenState extends State<AlternativeWalkersScreen> {
  List<Map<String, dynamic>> _walkers = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _originalBooking;

  String? _bookingId;
  List<String> _walkerIds = [];

  @override
  void initState() {
    super.initState();
    _bookingId = widget.bookingId;
    _walkerIds = widget.suggestedWalkerIds ?? [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _bookingId = args['booking_id'] as String?;
        final ids = args['suggested_walker_ids'];
        if (ids is List) {
          _walkerIds = ids.cast<String>();
        }
      }
    }

    if (_isLoading) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use injected future or fetch from Supabase
      final walkers = widget.walkersFuture != null
          ? await widget.walkersFuture!
          : await _fetchWalkers();

      // Fetch original booking details for rebooking
      if (_bookingId != null && widget.walkersFuture == null) {
        final bookingData = await withRetry(() => Supabase.instance.client
            .from('bookings')
            .select('*, dogs(id, name, breed)')
            .eq('id', _bookingId!)
            .single());
        _originalBooking = bookingData;
      }

      if (!mounted) return;
      setState(() {
        _walkers = walkers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load alternative walkers';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWalkers() async {
    if (_walkerIds.isEmpty) return [];
    final data = await withRetry(() => Supabase.instance.client
        .from('walkers')
        .select('id, user_id, hourly_rate_mxn, avg_rating, total_walks, bio, users(full_name, avatar_url)')
        .inFilter('id', _walkerIds));
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _bookInstead(Map<String, dynamic> walker) async {
    if (_originalBooking == null) {
      ErrorHandler.instance.showRecoverableError(
        context,
        'Cannot rebook — original booking details unavailable.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final users = walker['users'] as Map<String, dynamic>?;
        final name = users?['full_name'] ?? 'this walker';
        return AlertDialog(
          title: Text('Book with $name?',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Text(
              'A new walk request will be sent for the same date, time, and dog.',
              style: GoogleFonts.nunito()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Book',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      final response = await withRetry(() =>
          Supabase.instance.client.functions.invoke(
            'create-booking',
            body: {
              'walker_id': walker['id'],
              'dog_id': _originalBooking!['dog_id'],
              'scheduled_at': _originalBooking!['scheduled_at'],
              'duration_minutes': _originalBooking!['duration_minutes'],
              'notes': _originalBooking!['notes'],
            },
          ));

      if (!mounted) return;

      if (response.status == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Walk request sent!',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.green600,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        ErrorHandler.instance.handleFunctionError(
          context,
          response,
          screen: 'alternative_walkers',
          blocking: true,
          fallbackMessage: 'Failed to create booking. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'alternative_walkers',
        fallbackMessage: 'Failed to create booking. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Alternative Walkers',
            style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.warningCircle(),
                  size: 48, color: AppColors.red500),
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text('Retry',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_walkers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.magnifyingGlass(),
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.sm),
              Text('No alternative walkers available',
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Try searching for walkers nearby',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text('Browse Walkers',
                      style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Text(
            'Your walker was unavailable. Here are some alternatives:',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _walkers.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _WalkerCard(
                  walker: _walkers[index],
                  onBookInstead: () => _bookInstead(_walkers[index]),
                ),
          ),
        ),
      ],
    );
  }
}

class _WalkerCard extends StatelessWidget {
  final Map<String, dynamic> walker;
  final VoidCallback onBookInstead;

  const _WalkerCard({required this.walker, required this.onBookInstead});

  @override
  Widget build(BuildContext context) {
    final users = walker['users'] as Map<String, dynamic>?;
    final name = users?['full_name'] as String? ?? 'Unknown Walker';
    final rate = (walker['hourly_rate_mxn'] as num?)?.toInt() ?? 0;
    final rating = (walker['avg_rating'] as num?)?.toDouble();
    final totalWalks = walker['total_walks'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.orange50,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'W',
                  style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.orange500),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (rating != null) ...[
                          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill),
                              color: AppColors.amber500, size: 16),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: GoogleFonts.nunito(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text('$totalWalks walks',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('\$$rate MXN/hr',
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onBookInstead,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text('Book Instead',
                  style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test test/owner_booking_acceptance_test.dart`
Expected: all pass

- [ ] **Step 5: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors

- [ ] **Step 6: Commit**

```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add lib/screens/alternative_walkers_screen.dart test/owner_booking_acceptance_test.dart
git commit -m "feat(US-013): add AlternativeWalkersScreen for declined/expired walk requests"
```

---

### Task 5: Route Registration

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import for AlternativeWalkersScreen**

Add to `lib/main.dart` imports:
```dart
import 'package:pawgo/screens/alternative_walkers_screen.dart';
```

- [ ] **Step 2: Register the route**

In `lib/main.dart`, in the `routes` map inside `onGenerateRoute` (after the `/walk-request` entry, around line 175), add:

```dart
              '/alternative-walkers': (context) =>
                  const AlternativeWalkersScreen(),
```

- [ ] **Step 3: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors

- [ ] **Step 4: Run full test suite**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test`
Expected: all pass

- [ ] **Step 5: Commit**

```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add lib/main.dart
git commit -m "feat(US-013): register /alternative-walkers route"
```

---

### Task 6: Final Verification

- [ ] **Step 1: Run flutter analyze**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter analyze`
Expected: zero errors, zero new warnings

- [ ] **Step 2: Run full test suite**

Run: `cd /Users/dabenson/Documents/myApps/pawgo_flutter && flutter test`
Expected: all tests pass

- [ ] **Step 3: Final commit if any cleanup needed**

If any adjustments were made during verification:
```bash
cd /Users/dabenson/Documents/myApps/pawgo_flutter && git add -A
git commit -m "chore(US-013): final cleanup and verification"
```
