import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PawgoApp());
    expect(find.text('Pawgo'), findsOneWidget);
  });
}
