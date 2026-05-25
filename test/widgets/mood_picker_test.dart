import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/l10n/app_localizations.dart';
import 'package:pawgo/models/temperament.dart';
import 'package:pawgo/widgets/mood_picker.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders one card per temperament', (tester) async {
    await tester.pumpWidget(_wrap(MoodPicker(value: null, onChanged: (_) {})));
    await tester.pumpAndSettle();
    for (final t in Temperament.values) {
      expect(find.text(t.emoji), findsOneWidget);
    }
  });

  testWidgets('tap fires onChanged with the tapped value', (tester) async {
    Temperament? picked;
    await tester.pumpWidget(
      _wrap(MoodPicker(value: null, onChanged: (v) => picked = v)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('😄'));
    await tester.pumpAndSettle();
    expect(picked, Temperament.playful);
  });
}
