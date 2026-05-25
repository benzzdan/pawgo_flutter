import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/walker_hero_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('WalkerHeroCard', () {
    testWidgets('renders name + rating + total-walks chip + initial fallback',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Maria Garcia',
          rating: 4.7,
          totalWalks: 42,
          isVerified: true,
        ),
      ));

      expect(find.text('Maria Garcia'), findsOneWidget);
      // Rating + total-walks shown.
      expect(find.text('4.7'), findsOneWidget);
      expect(find.textContaining('42'), findsWidgets);
      // No avatarUrl → fallback initials block ("MG").
      expect(find.text('MG'), findsOneWidget);
    });

    testWidgets('renders network avatar when an avatarUrl is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Carlos Ruiz',
          rating: 4.9,
          totalWalks: 100,
          avatarUrl: 'https://example.com/c.jpg',
          isVerified: true,
        ),
      ));

      // Avatar URL routes to an Image.network — initials should NOT show
      // up while the network image attempts to load.
      expect(find.text('CR'), findsNothing);
    });

    testWidgets('renders "New" when rating is null', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Ana Lopez',
          rating: null,
          totalWalks: 0,
          isVerified: false,
        ),
      ));

      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('renders distance pill when distanceKm is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Pedro Sanchez',
          rating: 4.5,
          totalWalks: 30,
          isVerified: true,
          distanceKm: 1.5,
        ),
      ));

      // "1.5 km" or "1.5km" — match by partial text.
      expect(find.textContaining('1.5'), findsWidgets);
      expect(find.textContaining('km'), findsWidgets);
    });

    testWidgets('omits distance pill when distanceKm is null', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Sofia Hernandez',
          rating: 4.8,
          totalWalks: 50,
          isVerified: true,
        ),
      ));

      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('renders verified badge only when isVerified is true',
        (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: 'Luis Martinez',
          rating: 4.6,
          totalWalks: 60,
          isVerified: false,
        ),
      ));
      // Verified copy uses the localized "Verified" pill, which only renders
      // when isVerified is true.
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('initials fall back to "?" when name is empty', (tester) async {
      await tester.pumpWidget(wrap(
        const WalkerHeroCard(
          name: '',
          rating: null,
          totalWalks: 0,
          isVerified: false,
        ),
      ));

      expect(find.text('?'), findsOneWidget);
    });
  });
}
