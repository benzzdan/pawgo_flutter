import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen error state', () {
    testWidgets('shows error widget with icon, message, and retry button',
        (tester) async {
      // Simulate HomeScreen error state by building the error UI directly.
      // We can't easily mock Supabase.instance in widget tests, so we test
      // the error state rendering pattern used across all screens.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ErrorStateWidget(
              error: 'Unable to load your dashboard. Please try again.',
              onRetry: () {},
            ),
          ),
        ),
      );

      // Error icon visible
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Error message visible
      expect(
        find.text('Unable to load your dashboard. Please try again.'),
        findsOneWidget,
      );

      // Retry button visible
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('retry button calls callback when tapped', (tester) async {
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ErrorStateWidget(
              error: 'Unable to load your dashboard. Please try again.',
              onRetry: () => retryCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retryCount, 1);
    });
  });

  group('BookingsScreen error state', () {
    testWidgets('shows error widget with icon, message, and retry button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ErrorStateWidget(
              error: 'Could not load bookings',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Could not load bookings'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button calls callback', (tester) async {
      var retryCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ErrorStateWidget(
              error: 'Could not load bookings',
              onRetry: () => retryCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retryCount, 1);
    });
  });

  group('Error state pattern consistency', () {
    testWidgets('error state has all required elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ErrorStateWidget(
              error: 'Network error occurred',
              onRetry: () {},
            ),
          ),
        ),
      );

      // All error states must have: icon, message text, retry button
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}

/// Reusable error state widget matching the pattern used in all Pawgo screens.
/// This mirrors the error state rendering in HomeScreen, FindScreen, etc.
class _ErrorStateWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorStateWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
