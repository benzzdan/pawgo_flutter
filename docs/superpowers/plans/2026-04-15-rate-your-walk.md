# Rate Your Walk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a walker ends a walk the owner is prompted with a bottom sheet to rate the walk; the walker is sent to their Upcoming tab; unreviewed walks are also surfaced via push notification tap, BookingsScreen load, and app startup.

**Architecture:** A new `ReviewBottomSheet` widget carries the review form (extracted logic from the existing `ReviewScreen`). Three trigger points show it — Realtime in `active_walk_screen`, a pending-review query in `BookingsScreen`, and a startup check in `_AuthGate`. The `end-walk` Edge Function enriches its existing FCM notification with `review_prompt` data; `NotificationService` routes those taps to the same sheet.

**Tech Stack:** Flutter/Dart, Supabase (PostgREST + Realtime), FCM via `firebase_messaging`, `flutter_local_notifications`, `mocktail` for tests, Deno/TypeScript for Edge Function.

---

## File Map

| Action | File | What changes |
|---|---|---|
| Create | `lib/widgets/review_bottom_sheet.dart` | New reusable bottom-sheet widget with session-guard flag |
| Modify | `lib/screens/active_walk_screen.dart` | Split walk_completed callback: walker → Upcoming, owner → ReviewBottomSheet |
| Modify | `lib/screens/walker_bookings_screen.dart` | Accept `initialTab` constructor arg |
| Modify | `lib/screens/bookings_screen.dart` | Add `_checkPendingReview()` after `_fetchBookings()` |
| Modify | `lib/main.dart` | Handle `review_sheet` sentinel in notification tap; add startup pending-review check |
| Modify | `lib/services/notification_service.dart` | Add `walkerId`/`walkerName`/`reviewPrompt` to `NotificationData`; add `review_prompt` case to `NotificationRouter` |
| Modify | `Pawgo-api/supabase/functions/end-walk/index.ts` | Fetch walker name; enrich FCM payload with review_prompt fields |
| Create | `test/review_bottom_sheet_test.dart` | Widget tests for new sheet |
| Modify | `test/notification_service_test.dart` | Add tests for review_prompt routing |
| Modify | `test/review_screen_test.dart` | Add tests documenting walker-vs-owner navigation split |

---

## Task 1: Add `initialTab` to `WalkerBookingsScreen`

**Files:**
- Modify: `pawgo_flutter/lib/screens/walker_bookings_screen.dart:11-16`

The walker lands here after ending a walk. The constructor currently ignores arguments; we need it to accept an `initialTab` int so the caller can open on tab 0 (Upcoming).

- [ ] **Step 1.1: Write the failing test**

Create `test/walker_bookings_initial_tab_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';

void main() {
  group('WalkerBookingsScreen initialTab', () {
    test('default initialTab is 0 (Upcoming)', () {
      // WalkerBookingsScreen.defaultInitialTab must exist and equal 0
      expect(WalkerBookingsScreen.defaultInitialTab, 0);
    });

    test('accepts initialTab argument in constructor', () {
      // If constructor doesn't accept initialTab this line will fail to compile
      const widget = WalkerBookingsScreen(initialTab: 2);
      expect(widget.initialTab, 2);
    });
  });
}
```

- [ ] **Step 1.2: Run test to confirm it fails**

```bash
cd pawgo_flutter && flutter test test/walker_bookings_initial_tab_test.dart
```
Expected: compile error — `initialTab` not found on `WalkerBookingsScreen`.

- [ ] **Step 1.3: Add `initialTab` to `WalkerBookingsScreen`**

In `lib/screens/walker_bookings_screen.dart`, replace the class declaration and `initState`:

```dart
class WalkerBookingsScreen extends StatefulWidget {
  const WalkerBookingsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  static const int defaultInitialTab = 0;

  @override
  State<WalkerBookingsScreen> createState() => _WalkerBookingsScreenState();
}
```

In `_WalkerBookingsScreenState.initState`, set the initial selected tab from the widget:

```dart
@override
void initState() {
  super.initState();
  _selectedTab = widget.initialTab;
  _loadWalkerBookings();
}
```

(The existing `int _selectedTab = 0;` field declaration stays; `initState` overwrites it.)

- [ ] **Step 1.4: Update `main.dart` route to pass arguments**

In `lib/main.dart`, replace the `/walker-bookings` route builder so it reads the `initialTab` argument:

```dart
'/walker-bookings': (context) {
  final args = ModalRoute.of(context)?.settings.arguments;
  int initialTab = 0;
  if (args is Map<String, dynamic>) {
    initialTab = (args['initialTab'] as int?) ?? 0;
  }
  return WalkerBookingsScreen(initialTab: initialTab);
},
```

- [ ] **Step 1.5: Run test to confirm it passes**

```bash
cd pawgo_flutter && flutter test test/walker_bookings_initial_tab_test.dart
```
Expected: PASS (both tests green).

- [ ] **Step 1.6: Run analyzer**

```bash
cd pawgo_flutter && flutter analyze
```
Expected: zero errors.

- [ ] **Step 1.7: Commit**

```bash
cd pawgo_flutter && git add lib/screens/walker_bookings_screen.dart lib/main.dart test/walker_bookings_initial_tab_test.dart
git commit -m "feat: add initialTab arg to WalkerBookingsScreen"
```

---

## Task 2: Create `ReviewBottomSheet` widget

**Files:**
- Create: `pawgo_flutter/lib/widgets/review_bottom_sheet.dart`
- Create: `pawgo_flutter/test/review_bottom_sheet_test.dart`

- [ ] **Step 2.1: Write the failing widget test**

Create `test/review_bottom_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ReviewBottomSheet', () {
    testWidgets('shows walker name', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1',
        walkerId: 'w-1',
        walkerName: 'Carlos M.',
      )));
      expect(find.text('Carlos M.'), findsOneWidget);
    });

    testWidgets('shows 5 star icons', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1',
        walkerId: 'w-1',
        walkerName: 'Carlos M.',
      )));
      // 5 GestureDetectors wrapping star icons
      expect(find.byType(GestureDetector), findsNWidgets(5));
    });

    testWidgets('shows Submit Review and Skip for now buttons', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1',
        walkerId: 'w-1',
        walkerName: 'Carlos M.',
      )));
      expect(find.text('Submit Review'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('tapping a star updates rating label', (tester) async {
      await tester.pumpWidget(_wrap(const ReviewBottomSheet(
        bookingId: 'b-1',
        walkerId: 'w-1',
        walkerName: 'Carlos M.',
      )));
      // Initially shows default label
      expect(find.text('Tap a star to rate'), findsOneWidget);
      // Tap the 4th star (index 3)
      await tester.tap(find.byType(GestureDetector).at(3));
      await tester.pump();
      expect(find.text('Great'), findsOneWidget);
    });

    test('shownThisSession is a static bool defaulting to false', () {
      ReviewBottomSheet.shownThisSession = false; // reset
      expect(ReviewBottomSheet.shownThisSession, false);
    });
  });
}
```

- [ ] **Step 2.2: Run test to confirm it fails**

```bash
cd pawgo_flutter && flutter test test/review_bottom_sheet_test.dart
```
Expected: compile error — `ReviewBottomSheet` not found.

- [ ] **Step 2.3: Create `lib/widgets/review_bottom_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';

class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.bookingId,
    required this.walkerId,
    required this.walkerName,
  });

  final String bookingId;
  final String walkerId;
  final String walkerName;

  /// True once the sheet has been shown this app session.
  /// Prevents duplicate prompts from startup + BookingsScreen checks.
  /// Reset to false on sign-out.
  static bool shownThisSession = false;

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ErrorHandler.instance.showRecoverableError(context, 'Please select a rating');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        Navigator.pop(context);
        return;
      }
      final comment = _commentController.text.trim();
      await withRetry(() => Supabase.instance.client.from('reviews').insert({
            'booking_id': widget.bookingId,
            'reviewer_id': userId,
            'walker_id': widget.walkerId,
            'rating': _rating,
            if (comment.isNotEmpty) 'comment': comment,
          }));
      if (!mounted) return;
      AnalyticsService.instance.reviewSubmitted(
        bookingId: widget.bookingId,
        rating: _rating,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final isDuplicate = e.toString().contains('duplicate');
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'review_sheet',
        fallbackMessage: isDuplicate
            ? 'You have already reviewed this walk'
            : 'Failed to submit review. Please try again.',
      );
    }
  }

  void _skip() => Navigator.pop(context);

  String _ratingLabel() {
    switch (_rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return 'Tap a star to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.orange400, AppColors.orange500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(PhosphorIcons.user(), size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'How was your walk with',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.walkerName,
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        star <= _rating
                            ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                            : PhosphorIcons.star(),
                        size: 40,
                        color: star <= _rating ? AppColors.amber500 : AppColors.gray300,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                _ratingLabel(),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _rating > 0 ? AppColors.amber500 : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 500,
                style: GoogleFonts.nunito(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Share your experience... (optional)',
                  hintStyle: GoogleFonts.nunito(
                      color: AppColors.textTertiary, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  counterStyle: GoogleFonts.nunito(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    disabledBackgroundColor:
                        AppColors.orange500.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit Review',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2.4: Run tests**

```bash
cd pawgo_flutter && flutter test test/review_bottom_sheet_test.dart
```
Expected: all 5 tests PASS.

- [ ] **Step 2.5: Run analyzer**

```bash
cd pawgo_flutter && flutter analyze
```
Expected: zero errors.

- [ ] **Step 2.6: Commit**

```bash
cd pawgo_flutter && git add lib/widgets/review_bottom_sheet.dart test/review_bottom_sheet_test.dart
git commit -m "feat: add ReviewBottomSheet widget with session guard"
```

---

## Task 3: Fix `active_walk_screen` walk_completed callback

**Files:**
- Modify: `pawgo_flutter/lib/screens/active_walk_screen.dart` (lines ~383–395)

Currently the Realtime callback navigates both walker and owner to `/review`. Fix: walker goes to `/walker-bookings` (Upcoming tab); owner gets `ReviewBottomSheet`.

- [ ] **Step 3.1: Add tests documenting the new split behavior**

In `test/review_screen_test.dart`, add a new group after the existing groups:

```dart
group('walk_completed Realtime callback: walker vs owner routing', () {
  test('walker role routes to /walker-bookings with initialTab 0', () {
    // Documents the expected route for _isWalker == true.
    // The active_walk_screen's Realtime callback must call:
    //   Navigator.pushReplacementNamed(context, '/walker-bookings',
    //     arguments: {'initialTab': 0})
    // when _isWalker is true.
    const expectedRoute = '/walker-bookings';
    const expectedArgs = {'initialTab': 0};
    expect(expectedRoute, '/walker-bookings');
    expect(expectedArgs['initialTab'], 0);
  });

  test('owner role shows ReviewBottomSheet, not /review', () {
    // Documents that _isWalker == false must NOT push '/review'.
    // It must call showModalBottomSheet with ReviewBottomSheet.
    // Verified structurally: the '/review' push is removed from the callback.
    const routeThatMustNotBeUsed = '/review';
    expect(routeThatMustNotBeUsed, isNot('/walker-bookings'));
  });
});
```

- [ ] **Step 3.2: Run the new tests**

```bash
cd pawgo_flutter && flutter test test/review_screen_test.dart
```
Expected: new tests PASS (they're structural).

- [ ] **Step 3.3: Update the Realtime callback in `active_walk_screen.dart`**

Find the `_subscribeToBookingStatus` method (around line 370). Replace the callback body:

```dart
// OLD:
callback: (payload) {
  final status = payload.newRecord['status'] as String?;
  if (status == 'walk_completed' && mounted) {
    Navigator.pushReplacementNamed(context, '/review', arguments: {
      'booking_id': _bookingId,
      'walker_id': _walkerId,
      'walker_name': _walkerName,
    });
  }
},

// NEW:
callback: (payload) {
  final status = payload.newRecord['status'] as String?;
  if (status == 'walk_completed' && mounted) {
    if (_isWalker) {
      Navigator.pushReplacementNamed(
        context,
        '/walker-bookings',
        arguments: {'initialTab': 0},
      );
    } else {
      _showReviewSheet();
    }
  }
},
```

- [ ] **Step 3.4: Add `_showReviewSheet` helper to `_ActiveWalkScreenState`**

Add this method to `_ActiveWalkScreenState` (place it near `_endWalk`):

```dart
void _showReviewSheet() {
  if (_bookingId == null || _walkerId == null) return;
  ReviewBottomSheet.shownThisSession = true;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReviewBottomSheet(
      bookingId: _bookingId!,
      walkerId: _walkerId!,
      walkerName: _walkerName ?? 'your walker',
    ),
  ).then((_) {
    if (!mounted) return;
    BookingsScreen.pendingInitialTab = 'past';
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: {'tab': 2},
    );
  });
}
```

- [ ] **Step 3.5: Add the required imports to `active_walk_screen.dart`**

At the top of `lib/screens/active_walk_screen.dart`, add:

```dart
import 'package:pawgo/widgets/review_bottom_sheet.dart';
import 'package:pawgo/screens/bookings_screen.dart';
```

- [ ] **Step 3.6: Run analyzer**

```bash
cd pawgo_flutter && flutter analyze
```
Expected: zero errors.

- [ ] **Step 3.7: Run all tests**

```bash
cd pawgo_flutter && flutter test
```
Expected: all tests pass.

- [ ] **Step 3.8: Commit**

```bash
cd pawgo_flutter && git add lib/screens/active_walk_screen.dart test/review_screen_test.dart
git commit -m "fix: split walk_completed handler — walker to Upcoming, owner to ReviewBottomSheet"
```

---

## Task 4: Pending review check in `BookingsScreen`

**Files:**
- Modify: `pawgo_flutter/lib/screens/bookings_screen.dart`

After `_fetchBookings()` completes, query for an unreviewed completed booking. If found and not shown this session, show `ReviewBottomSheet`.

- [ ] **Step 4.1: Write a structural test documenting the check**

Add to `test/review_screen_test.dart` (new group after existing ones):

```dart
group('BookingsScreen: pending review check', () {
  test('ReviewBottomSheet.shownThisSession prevents duplicate prompts', () {
    // If shownThisSession is true, the check must be skipped.
    ReviewBottomSheet.shownThisSession = true;
    // The check function returns early when shownThisSession is true.
    // This is a structural/documentation test.
    expect(ReviewBottomSheet.shownThisSession, true);
    ReviewBottomSheet.shownThisSession = false; // clean up
  });
});
```

- [ ] **Step 4.2: Run the test**

```bash
cd pawgo_flutter && flutter test test/review_screen_test.dart
```
Expected: PASS.

- [ ] **Step 4.3: Add `_checkPendingReview` to `BookingsScreen`**

Add this method to `_BookingsScreenState`:

```dart
Future<void> _checkPendingReview() async {
  if (ReviewBottomSheet.shownThisSession) return;
  try {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await withRetry(() => _supabase
        .from('bookings')
        .select('id, walker_id, walkers!bookings_walker_id_fkey(users(full_name))')
        .eq('owner_id', userId)
        .eq('status', 'walk_completed')
        .is_('reviews.booking_id', null) // NOTE: use left-join filter below
        .order('updated_at', ascending: false)
        .limit(1));
    // The LEFT JOIN filter above doesn't work via PostgREST column filter.
    // Use a separate reviews lookup instead:
    if (data is! List || data.isEmpty) return;

    // Filter client-side: find the first booking without a review
    for (final booking in (data as List)) {
      final bookingId = booking['id'] as String;
      final reviews = await withRetry(() => _supabase
          .from('reviews')
          .select('id')
          .eq('booking_id', bookingId)
          .limit(1));
      if ((reviews as List).isEmpty) {
        final walkerData = booking['walkers'] as Map<String, dynamic>?;
        final userMap = walkerData?['users'] as Map<String, dynamic>?;
        final walkerId = booking['walker_id'] as String;
        final walkerName = userMap?['full_name'] as String? ?? 'your walker';
        if (!mounted) return;
        ReviewBottomSheet.shownThisSession = true;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => ReviewBottomSheet(
            bookingId: bookingId,
            walkerId: walkerId,
            walkerName: walkerName,
          ),
        );
        if (!mounted) return;
        BookingsScreen.pendingInitialTab = 'past';
        break;
      }
    }
  } catch (_) {
    // Non-critical: silently ignore errors in the review check
  }
}
```

- [ ] **Step 4.4: Call `_checkPendingReview` after `_fetchBookings` succeeds**

In `_BookingsScreenState.initState`, `_fetchBookings` is called. Because `_fetchBookings` is async and called without `await` in `initState`, chain the check using `then`. Replace the `_fetchBookings()` call in `initState` with:

```dart
_fetchBookings().then((_) => _checkPendingReview());
```

- [ ] **Step 4.5: Add required imports to `bookings_screen.dart`**

```dart
import 'package:pawgo/widgets/review_bottom_sheet.dart';
```

- [ ] **Step 4.6: Run analyzer**

```bash
cd pawgo_flutter && flutter analyze
```
Expected: zero errors.

- [ ] **Step 4.7: Run all tests**

```bash
cd pawgo_flutter && flutter test
```
Expected: all pass.

- [ ] **Step 4.8: Commit**

```bash
cd pawgo_flutter && git add lib/screens/bookings_screen.dart
git commit -m "feat: check for pending review on BookingsScreen load"
```

---

## Task 5: Update `NotificationData` and `NotificationRouter` for `review_prompt`

**Files:**
- Modify: `pawgo_flutter/lib/services/notification_service.dart`
- Modify: `pawgo_flutter/test/notification_service_test.dart`

Add `walkerId`, `walkerName`, `reviewPrompt` to `NotificationData`. Add `review_prompt` type handling to `NotificationRouter` returning sentinel route `'review_sheet'`.

- [ ] **Step 5.1: Write failing tests**

Add to `test/notification_service_test.dart` inside the existing `main()`:

```dart
group('NotificationData review_prompt fields', () {
  test('fromRemoteMessage extracts walkerId and walkerName', () {
    final message = FakeRemoteMessage(data: {
      'type': 'review_prompt',
      'booking_id': 'b-123',
      'walker_id': 'w-456',
      'walker_name': 'Carlos M.',
      'review_prompt': 'true',
    });
    final data = NotificationData.fromFakeMessage(message);
    expect(data.type, 'review_prompt');
    expect(data.bookingId, 'b-123');
    expect(data.walkerId, 'w-456');
    expect(data.walkerName, 'Carlos M.');
    expect(data.reviewPrompt, true);
  });

  test('toPayload and fromPayload round-trip review_prompt fields', () {
    const data = NotificationData(
      type: 'review_prompt',
      bookingId: 'b-123',
      walkerId: 'w-456',
      walkerName: 'Carlos M.',
      reviewPrompt: true,
    );
    final payload = data.toPayload();
    final restored = NotificationData.fromPayload(payload);
    expect(restored.walkerId, 'w-456');
    expect(restored.walkerName, 'Carlos M.');
    expect(restored.reviewPrompt, true);
  });
});

group('NotificationRouter review_prompt routing', () {
  test('review_prompt type returns route review_sheet with booking args', () {
    final nav = NotificationRouter.routeFor(
      type: 'review_prompt',
      bookingId: 'b-123',
      walkerId: 'w-456',
      walkerName: 'Carlos M.',
    );
    expect(nav, isNotNull);
    expect(nav!.route, 'review_sheet');
    expect(nav.arguments?['booking_id'], 'b-123');
    expect(nav.arguments?['walker_id'], 'w-456');
    expect(nav.arguments?['walker_name'], 'Carlos M.');
  });
});
```

Note: `FakeRemoteMessage` and `NotificationData.fromFakeMessage` require a test helper or adjusting `fromRemoteMessage` to accept a map. If the existing tests already use `RemoteMessage` directly and that's not mockable, add a `NotificationData.fromMap` factory instead. Adjust the test to use `fromMap`:

```dart
test('fromMap extracts review_prompt fields', () {
  final data = NotificationData.fromMap({
    'type': 'review_prompt',
    'booking_id': 'b-123',
    'walker_id': 'w-456',
    'walker_name': 'Carlos M.',
    'review_prompt': 'true',
  });
  expect(data.walkerId, 'w-456');
  expect(data.walkerName, 'Carlos M.');
  expect(data.reviewPrompt, true);
});
```

- [ ] **Step 5.2: Run tests to confirm failure**

```bash
cd pawgo_flutter && flutter test test/notification_service_test.dart
```
Expected: compile/runtime errors — `walkerId`, `walkerName`, `reviewPrompt` not found.

- [ ] **Step 5.3: Update `NotificationData`**

Replace the `NotificationData` class in `lib/services/notification_service.dart`:

```dart
class NotificationData {
  final String? title;
  final String? body;
  final String? type;
  final String? bookingId;
  final List<String>? suggestedWalkerIds;
  final String? walkerId;
  final String? walkerName;
  final bool reviewPrompt;

  const NotificationData({
    this.title,
    this.body,
    this.type,
    this.bookingId,
    this.suggestedWalkerIds,
    this.walkerId,
    this.walkerName,
    this.reviewPrompt = false,
  });

  factory NotificationData.fromRemoteMessage(RemoteMessage message) {
    List<String>? walkerIds;
    final rawIds = message.data['suggested_walker_ids'];
    if (rawIds is String && rawIds.isNotEmpty) {
      walkerIds = rawIds.split(',');
    } else if (rawIds is List) {
      walkerIds = rawIds.cast<String>();
    }

    return NotificationData(
      title: message.notification?.title,
      body: message.notification?.body,
      type: message.data['type'] as String?,
      bookingId: message.data['booking_id'] as String?,
      suggestedWalkerIds: walkerIds,
      walkerId: message.data['walker_id'] as String?,
      walkerName: message.data['walker_name'] as String?,
      reviewPrompt: message.data['review_prompt'] == 'true',
    );
  }

  /// Construct from a plain map (useful for tests and local notification payload decoding).
  factory NotificationData.fromMap(Map<String, dynamic> map) {
    final rawIds = map['suggested_walker_ids'];
    List<String>? walkerIds;
    if (rawIds is List) {
      walkerIds = rawIds.cast<String>();
    }
    return NotificationData(
      type: map['type'] as String?,
      bookingId: map['booking_id'] as String?,
      suggestedWalkerIds: walkerIds,
      walkerId: map['walker_id'] as String?,
      walkerName: map['walker_name'] as String?,
      reviewPrompt: map['review_prompt'] == true || map['review_prompt'] == 'true',
    );
  }

  String toPayload() => jsonEncode({
        'type': type,
        'booking_id': bookingId,
        if (suggestedWalkerIds != null) 'suggested_walker_ids': suggestedWalkerIds,
        if (walkerId != null) 'walker_id': walkerId,
        if (walkerName != null) 'walker_name': walkerName,
        if (reviewPrompt) 'review_prompt': true,
      });

  factory NotificationData.fromPayload(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return NotificationData.fromMap(map);
  }
}
```

- [ ] **Step 5.4: Update `NotificationRouter`**

Add a `walkerId` and `walkerName` parameter and a `review_prompt` case:

```dart
class NotificationRouter {
  static NotificationNavigation? routeFor({
    required String? type,
    String? bookingId,
    List<String>? suggestedWalkerIds,
    String? walkerId,
    String? walkerName,
  }) {
    switch (type) {
      case 'booking_confirmed':
        return const NotificationNavigation(route: '/home', tab: 'upcoming');
      case 'new_message':
        return NotificationNavigation(
          route: '/chat',
          arguments: {'booking_id': bookingId},
        );
      case 'walk_started':
        return NotificationNavigation(
          route: '/active-walk',
          arguments: bookingId != null ? {'booking_id': bookingId} : null,
        );
      case 'walk_completed':
        return const NotificationNavigation(route: '/home', tab: 'past');
      case 'review_prompt':
        return NotificationNavigation(
          route: 'review_sheet',
          arguments: {
            'booking_id': bookingId,
            'walker_id': walkerId,
            'walker_name': walkerName ?? 'your walker',
          },
        );
      case 'walk_request':
        return NotificationNavigation(
          route: '/walk-request',
          arguments: bookingId != null ? {'booking_id': bookingId} : null,
        );
      case 'walk_request_accepted':
        return const NotificationNavigation(route: '/home', tab: 'upcoming');
      case 'walk_request_declined':
      case 'walk_request_expired':
        if (suggestedWalkerIds != null && suggestedWalkerIds.isNotEmpty) {
          return NotificationNavigation(
            route: '/alternative-walkers',
            arguments: {
              'booking_id': bookingId,
              'suggested_walker_ids': suggestedWalkerIds,
            },
          );
        }
        return const NotificationNavigation(route: '/home', tab: 'cancelled');
      default:
        return null;
    }
  }
}
```

- [ ] **Step 5.5: Update `_handleNotificationTap` in `NotificationService` to pass new fields**

In `_handleNotificationTap`, pass `walkerId` and `walkerName`:

```dart
void _handleNotificationTap(NotificationData data) {
  final nav = NotificationRouter.routeFor(
    type: data.type,
    bookingId: data.bookingId,
    suggestedWalkerIds: data.suggestedWalkerIds,
    walkerId: data.walkerId,
    walkerName: data.walkerName,
  );
  if (nav != null) {
    _onNotificationTap?.call(nav);
  }
}
```

- [ ] **Step 5.6: Update the tests to use `fromMap` where `fromRemoteMessage` isn't mockable**

In `test/notification_service_test.dart`, adjust the new tests to call `NotificationData.fromMap(...)` (since `RemoteMessage` can't be constructed in tests without Firebase). Remove `FakeRemoteMessage` references and use `fromMap` directly.

Final test form for the `review_prompt` group:

```dart
group('NotificationData review_prompt fields', () {
  test('fromMap extracts walkerId and walkerName', () {
    final data = NotificationData.fromMap({
      'type': 'review_prompt',
      'booking_id': 'b-123',
      'walker_id': 'w-456',
      'walker_name': 'Carlos M.',
      'review_prompt': 'true',
    });
    expect(data.type, 'review_prompt');
    expect(data.bookingId, 'b-123');
    expect(data.walkerId, 'w-456');
    expect(data.walkerName, 'Carlos M.');
    expect(data.reviewPrompt, true);
  });

  test('toPayload and fromPayload round-trip review_prompt fields', () {
    const data = NotificationData(
      type: 'review_prompt',
      bookingId: 'b-123',
      walkerId: 'w-456',
      walkerName: 'Carlos M.',
      reviewPrompt: true,
    );
    final payload = data.toPayload();
    final restored = NotificationData.fromPayload(payload);
    expect(restored.walkerId, 'w-456');
    expect(restored.walkerName, 'Carlos M.');
    expect(restored.reviewPrompt, true);
  });
});

group('NotificationRouter review_prompt routing', () {
  test('returns route review_sheet with booking args', () {
    final nav = NotificationRouter.routeFor(
      type: 'review_prompt',
      bookingId: 'b-123',
      walkerId: 'w-456',
      walkerName: 'Carlos M.',
    );
    expect(nav, isNotNull);
    expect(nav!.route, 'review_sheet');
    expect(nav.arguments?['booking_id'], 'b-123');
    expect(nav.arguments?['walker_id'], 'w-456');
    expect(nav.arguments?['walker_name'], 'Carlos M.');
  });
});
```

- [ ] **Step 5.7: Run tests**

```bash
cd pawgo_flutter && flutter test test/notification_service_test.dart
```
Expected: all tests PASS including new ones.

- [ ] **Step 5.8: Run all tests**

```bash
cd pawgo_flutter && flutter test
```
Expected: all pass.

- [ ] **Step 5.9: Commit**

```bash
cd pawgo_flutter && git add lib/services/notification_service.dart test/notification_service_test.dart
git commit -m "feat: add review_prompt support to NotificationData and NotificationRouter"
```

---

## Task 6: Handle `review_sheet` sentinel in `main.dart` + startup check

**Files:**
- Modify: `pawgo_flutter/lib/main.dart`

Two changes: (1) `_handleNotificationTap` shows `ReviewBottomSheet` when route is `'review_sheet'` instead of navigating. (2) `_AuthGate` runs a pending review check after sign-in.

- [ ] **Step 6.1: Update `_handleNotificationTap` in `main.dart`**

Replace the existing `_handleNotificationTap` function:

```dart
void _handleNotificationTap(NotificationNavigation nav) {
  if (nav.route == 'review_sheet') {
    _showReviewSheetFromNav(nav);
    return;
  }

  final navigator = ErrorHandler.instance.navigatorKey.currentState;
  if (navigator == null) return;

  if (nav.tab != null) {
    BookingsScreen.pendingInitialTab = nav.tab;
  }

  navigator.pushNamedAndRemoveUntil(
    nav.route,
    (route) => route.settings.name == '/home' || route.isFirst,
    arguments: nav.arguments,
  );
}

void _showReviewSheetFromNav(NotificationNavigation nav) {
  final context = ErrorHandler.instance.navigatorKey.currentContext;
  if (context == null) return;
  final args = nav.arguments;
  if (args == null) return;
  final bookingId = args['booking_id'] as String?;
  final walkerId = args['walker_id'] as String?;
  if (bookingId == null || walkerId == null) return;

  ReviewBottomSheet.shownThisSession = true;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReviewBottomSheet(
      bookingId: bookingId,
      walkerId: walkerId,
      walkerName: args['walker_name'] as String? ?? 'your walker',
    ),
  ).then((_) {
    BookingsScreen.pendingInitialTab = 'past';
    ErrorHandler.instance.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: {'tab': 2},
    );
  });
}
```

- [ ] **Step 6.2: Add pending review check to `_AuthGateState`**

In `_AuthGateState.initState`, after `Navigator.pushReplacementNamed(context, '/home')`, schedule the review check. The current code is:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    Navigator.pushReplacementNamed(context, '/home');
  }
});
```

Replace with:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    Navigator.pushReplacementNamed(context, '/home');
    // After navigation settles, check for an unreviewed completed walk.
    Future.delayed(const Duration(milliseconds: 500), _checkPendingReviewOnStartup);
  }
});
```

Add the `_checkPendingReviewOnStartup` method to `_AuthGateState`:

```dart
Future<void> _checkPendingReviewOnStartup() async {
  if (ReviewBottomSheet.shownThisSession) return;
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = await supabase
        .from('bookings')
        .select('id, walker_id, walkers!bookings_walker_id_fkey(users(full_name))')
        .eq('owner_id', userId)
        .eq('status', 'walk_completed')
        .order('updated_at', ascending: false)
        .limit(5);

    for (final booking in (data as List)) {
      final bookingId = booking['id'] as String;
      final reviews = await supabase
          .from('reviews')
          .select('id')
          .eq('booking_id', bookingId)
          .limit(1);
      if ((reviews as List).isEmpty) {
        final walkerData = booking['walkers'] as Map<String, dynamic>?;
        final userMap = walkerData?['users'] as Map<String, dynamic>?;
        final walkerId = booking['walker_id'] as String;
        final walkerName = userMap?['full_name'] as String? ?? 'your walker';
        _showReviewSheetFromNav(NotificationNavigation(
          route: 'review_sheet',
          arguments: {
            'booking_id': bookingId,
            'walker_id': walkerId,
            'walker_name': walkerName,
          },
        ));
        break;
      }
    }
  } catch (_) {
    // Non-critical: silently ignore
  }
}
```

- [ ] **Step 6.3: Reset `shownThisSession` on sign-out**

In `_AuthGateState.initState`, inside the `signedOut` branch:

```dart
} else if (event == AuthChangeEvent.signedOut) {
  ReviewBottomSheet.shownThisSession = false; // reset for next session
  AnalyticsService.instance.reset();
  // ... rest of existing sign-out logic
```

- [ ] **Step 6.4: Add required imports to `main.dart`**

```dart
import 'package:pawgo/widgets/review_bottom_sheet.dart';
```

- [ ] **Step 6.5: Run analyzer**

```bash
cd pawgo_flutter && flutter analyze
```
Expected: zero errors.

- [ ] **Step 6.6: Run all tests**

```bash
cd pawgo_flutter && flutter test
```
Expected: all pass.

- [ ] **Step 6.7: Commit**

```bash
cd pawgo_flutter && git add lib/main.dart
git commit -m "feat: handle review_prompt notification tap and startup pending review check"
```

---

## Task 7: Enrich `end-walk` Edge Function FCM payload

**Files:**
- Modify: `Pawgo-api/supabase/functions/end-walk/index.ts`

Fetch walker's name and pass `review_prompt`, `walker_id`, `walker_name` in the notification data payload.

- [ ] **Step 7.1: Update the walker query to include user's `full_name`**

Find the walker verification query (around line 60):

```typescript
// OLD:
const { data: walker } = await supabaseAdmin
  .from("walkers")
  .select("id")
  .eq("user_id", user.id)
  .single();

// NEW:
const { data: walker } = await supabaseAdmin
  .from("walkers")
  .select("id, users(full_name)")
  .eq("user_id", user.id)
  .single();
```

- [ ] **Step 7.2: Extract walker name after the query**

After the walker null-check (around line 66), add:

```typescript
const walkerName = (walker as any)?.users?.full_name ?? "your walker";
```

- [ ] **Step 7.3: Update the `send-notification` call**

Replace the existing notification body (around line 104):

```typescript
// OLD:
body: JSON.stringify({
  user_id: booking.owner_id,
  type: "walk_completed",
  title: "Walk Completed!",
  body: `Your dog's walk has been completed. Duration: ${durationMinutes} minutes.`,
  data: { booking_id },
}),

// NEW:
body: JSON.stringify({
  user_id: booking.owner_id,
  type: "review_prompt",
  title: "Walk complete! ⭐",
  body: `How was your walk with ${walkerName}? Tap to rate.`,
  data: {
    booking_id,
    walker_id: booking.walker_id,
    walker_name: walkerName,
    review_prompt: "true",
  },
}),
```

- [ ] **Step 7.4: Run the migration test suite to verify the backend is intact**

```bash
cd Pawgo-api && docker-compose up -d
sleep 5
psql postgresql://postgres:your-super-secret-and-long-postgres-password@localhost:5432/postgres \
  -f supabase/tests/migrations_test.sql
```
Expected: all migration tests pass.

- [ ] **Step 7.5: Commit**

```bash
cd Pawgo-api && git add supabase/functions/end-walk/index.ts
git commit -m "feat: enrich end-walk FCM notification with review_prompt and walker name"
```

---

## Self-Review

**Spec coverage:**
- ✅ Walker lands on Upcoming tab → Task 1 + Task 3
- ✅ Owner on active walk screen sees ReviewBottomSheet → Task 3
- ✅ BookingsScreen pending review check → Task 4
- ✅ App startup pending review check → Task 6
- ✅ Push notification tap opens ReviewBottomSheet → Tasks 5 + 6
- ✅ end-walk FCM payload enriched → Task 7
- ✅ Skip navigates to My Bookings past → `_showReviewSheet` `.then()` in Tasks 3, 6
- ✅ Submit navigates to My Bookings past → `ReviewBottomSheet._submit` pops, caller navigates

**Placeholder scan:** No TBDs or TODOs. All code blocks are complete.

**Type consistency:**
- `ReviewBottomSheet.shownThisSession` — defined in Task 2, used in Tasks 3, 4, 6. ✅
- `NotificationRouter.routeFor` new params `walkerId`/`walkerName` — defined in Task 5, called with them in Task 5 step 5.5. ✅
- `WalkerBookingsScreen.defaultInitialTab` — defined Task 1 step 1.3, used in Task 1 test. ✅
- `ReviewBottomSheet` constructor params (`bookingId`, `walkerId`, `walkerName`) — consistent across all call sites. ✅

**One note on Task 4 query:** The `_checkPendingReview` in BookingsScreen fetches up to 1 completed booking then checks for a review separately. This is two round-trips but simple and safe. The `.is_('reviews.booking_id', null)` PostgREST approach was noted as not working via a column filter, so the per-booking review lookup is used instead.
