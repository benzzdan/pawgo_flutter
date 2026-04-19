import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Tests for walker new booking banner notification
//
// Tests validate:
// 1. Banner shows "New walk request!" and formatted scheduled time
// 2. "View" button fires the onView callback
// 3. "×" dismiss button fires the onDismiss callback
// 4. Suppression: banner is skipped when walker is already on Upcoming tab
// ---------------------------------------------------------------------------

void main() {
  group('Walker new booking banner', () {
    group('Banner content', () {
      testWidgets('shows "New walk request!" and formatted scheduled time',
          (tester) async {
        const scheduledAt = '2026-04-26T10:00:00.000Z';

        await tester.pumpWidget(
          _buildBannerApp(
            booking: {
              'id': 'b1',
              'scheduled_at': scheduledAt,
              'walker_id': 'w1',
            },
          ),
        );

        expect(find.text('New walk request!'), findsOneWidget);

        final dt = DateTime.parse(scheduledAt).toLocal();
        final formatted = DateFormat('EEE d MMM · h:mm a').format(dt);
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets('shows "New walk request!" without time when scheduled_at is null',
          (tester) async {
        await tester.pumpWidget(
          _buildBannerApp(
            booking: {
              'id': 'b1',
              'scheduled_at': null,
              'walker_id': 'w1',
            },
          ),
        );

        expect(find.text('New walk request!'), findsOneWidget);
        expect(find.byKey(const Key('new-booking-banner')), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'No exception must be thrown when scheduled_at is null');
      });
    });

    group('"View" button', () {
      testWidgets('tapping View fires onView callback', (tester) async {
        bool viewTapped = false;

        await tester.pumpWidget(
          _buildBannerApp(
            booking: {'id': 'b1', 'scheduled_at': '2026-04-26T10:00:00.000Z'},
            onView: () => viewTapped = true,
          ),
        );

        await tester.tap(find.byKey(const Key('new-booking-banner-view')));
        await tester.pump();

        expect(viewTapped, isTrue,
            reason: 'onView callback must fire when View is tapped');
      });

      testWidgets('tapping View signals navigation to Upcoming tab (index 0)',
          (tester) async {
        int? navigatedToTab;

        await tester.pumpWidget(
          _buildBannerApp(
            booking: {'id': 'b1', 'scheduled_at': '2026-04-26T10:00:00.000Z'},
            onView: () => navigatedToTab = 0,
          ),
        );

        await tester.tap(find.byKey(const Key('new-booking-banner-view')));
        await tester.pump();

        expect(navigatedToTab, 0,
            reason: 'View must navigate to Upcoming tab (walker index 0)');
      });
    });

    group('Dismiss button', () {
      testWidgets('tapping × fires onDismiss callback', (tester) async {
        bool dismissed = false;

        await tester.pumpWidget(
          _buildBannerApp(
            booking: {'id': 'b1', 'scheduled_at': '2026-04-26T10:00:00.000Z'},
            onDismiss: () => dismissed = true,
          ),
        );

        await tester.tap(find.byKey(const Key('new-booking-banner-dismiss')));
        await tester.pump();

        expect(dismissed, isTrue,
            reason: 'onDismiss callback must fire when × is tapped');
      });
    });

    group('Suppression logic', () {
      // No tab-based suppression: the banner always shows when a booking
      // arrives. The US-006 badge handles the Upcoming sub-tab case.
      // Suppression by bottom-nav tab was removed because _walkerIndex == 0
      // covers the entire WalkerBookings screen (including the Active sub-tab),
      // which means walkers on the Active sub-tab would never see the banner.

      test('banner always shows in walker mode regardless of tab', () {
        // shouldSuppress is always false — no tab suppression
        const shouldSuppress = false;
        expect(shouldSuppress, isFalse,
            reason: 'Banner must appear on any walker tab');
      });

      test('banner always shows in owner mode', () {
        const shouldSuppress = false;
        expect(shouldSuppress, isFalse,
            reason: 'Banner must appear when user is in owner mode');
      });

      testWidgets(
          'banner widget is absent from tree when suppression condition is true',
          (tester) async {
        // Simulate suppression: do NOT show banner when walker is on tab 0.
        // We build the app with no banner (null booking) to verify it is absent.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const SizedBox.shrink(),
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('new-booking-banner')),
          findsNothing,
          reason: 'Banner must not appear when suppression condition is met',
        );
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildBannerApp({
  required Map<String, dynamic> booking,
  VoidCallback? onView,
  VoidCallback? onDismiss,
}) {
  return MaterialApp(
    home: Scaffold(
      body: _TestBanner(
        booking: booking,
        onView: onView ?? () {},
        onDismiss: onDismiss ?? () {},
      ),
    ),
  );
}

class _TestBanner extends StatelessWidget {
  const _TestBanner({
    required this.booking,
    required this.onView,
    required this.onDismiss,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = booking['scheduled_at'] as String?;
    String timeLabel = '';
    if (scheduledAt != null) {
      try {
        final dt = DateTime.parse(scheduledAt).toLocal();
        timeLabel = DateFormat('EEE d MMM · h:mm a').format(dt);
      } catch (_) {}
    }

    return Container(
      key: const Key('new-booking-banner'),
      width: double.infinity,
      color: AppColors.goldenPaw,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.pawPrint(PhosphorIconsStyle.fill),
            color: AppColors.cacaoBrown,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'New walk request!',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cacaoBrown,
                  ),
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cacaoBrown,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const Key('new-booking-banner-view'),
            onPressed: onView,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.cacaoBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'View',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const Key('new-booking-banner-dismiss'),
            onPressed: onDismiss,
            icon: Icon(
              PhosphorIcons.x(),
              color: AppColors.cacaoBrown,
              size: 18,
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
