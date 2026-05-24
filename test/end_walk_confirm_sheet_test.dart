import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/widgets/end_walk_confirm_sheet.dart';

void main() {
  testWidgets('renders title + Cancel + End Walk', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () => showEndWalkConfirmSheet(ctx),
          child: const Text('open'),
        )),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('End Walk?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('End Walk'), findsOneWidget);
  });

  testWidgets('Cancel returns false; End Walk returns true', (tester) async {
    bool? result;
    Future<void> openAndCheck(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) => ElevatedButton(
          onPressed: () async => result = await showEndWalkConfirmSheet(ctx),
          child: const Text('open'),
        )),
      ),
    ));

    await openAndCheck(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);

    await openAndCheck(tester);
    await tester.tap(find.text('End Walk'));
    await tester.pumpAndSettle();
    expect(result, true);
  });
}
