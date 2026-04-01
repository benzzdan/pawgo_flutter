import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawgo/services/theme_service.dart';

void main() {
  group('ThemeService', () {
    setUp(() {
      // Reset singleton state before each test
      ThemeService.instance.themeMode.value = ThemeMode.system;
    });

    test('initializes with system theme by default', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService.instance.initialize();
      expect(ThemeService.instance.themeMode.value, ThemeMode.system);
    });

    test('loads persisted dark theme', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await ThemeService.instance.initialize();
      expect(ThemeService.instance.themeMode.value, ThemeMode.dark);
    });

    test('loads persisted light theme', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      await ThemeService.instance.initialize();
      expect(ThemeService.instance.themeMode.value, ThemeMode.light);
    });

    test('setThemeMode persists and updates notifier', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService.instance.initialize();

      await ThemeService.instance.setThemeMode(ThemeMode.dark);
      expect(ThemeService.instance.themeMode.value, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('handles invalid persisted value gracefully', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'invalid_value'});
      await ThemeService.instance.initialize();
      expect(ThemeService.instance.themeMode.value, ThemeMode.system);
    });
  });

  group('Dark mode toggle widget', () {
    testWidgets('toggle switches theme mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService.instance.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.instance.themeMode,
              builder: (context, mode, _) {
                return Switch(
                  key: const Key('dark_mode_switch'),
                  value: mode == ThemeMode.dark,
                  onChanged: (on) {
                    ThemeService.instance
                        .setThemeMode(on ? ThemeMode.dark : ThemeMode.light);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Initially off (system mode)
      final switchFinder = find.byKey(const Key('dark_mode_switch'));
      expect(switchFinder, findsOneWidget);
      expect(
        tester.widget<Switch>(switchFinder).value,
        false,
      );

      // Tap to enable dark mode
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(ThemeService.instance.themeMode.value, ThemeMode.dark);
      expect(
        tester.widget<Switch>(switchFinder).value,
        true,
      );

      // Tap again to go back to light mode
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(ThemeService.instance.themeMode.value, ThemeMode.light);
      expect(
        tester.widget<Switch>(switchFinder).value,
        false,
      );
    });
  });
}
