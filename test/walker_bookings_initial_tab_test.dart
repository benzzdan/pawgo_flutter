import 'package:flutter_test/flutter_test.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';
void main() {
  group('WalkerBookingsScreen initialTab', () {
    test('default initialTab is 0', () {
      expect(WalkerBookingsScreen.defaultInitialTab, 0);
    });
    test('accepts initialTab in constructor', () {
      const widget = WalkerBookingsScreen(initialTab: 2);
      expect(widget.initialTab, 2);
    });
  });
}
