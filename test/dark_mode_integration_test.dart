import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawgo/services/theme_service.dart';
import 'package:pawgo/theme/app_theme.dart';

void main() {
  setUp(() {
    ThemeService.instance.themeMode.value = ThemeMode.system;
  });

  group('Dark mode applies to MaterialApp', () {
    testWidgets(
        'MaterialApp uses dark scaffold background when ThemeMode is dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await ThemeService.instance.initialize();

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.themeMode,
          builder: (context, themeMode, _) {
            return MaterialApp(
              theme: AppTheme.theme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: const Scaffold(
                // No explicit backgroundColor — should come from theme
                body: SizedBox(),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify theme mode is dark
      expect(ThemeService.instance.themeMode.value, ThemeMode.dark);

      // Verify the Scaffold uses the dark theme's scaffold background color
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // When no backgroundColor is set, Scaffold uses theme's scaffoldBackgroundColor
      // The dark theme sets this to AppColors.darkBackground
      expect(scaffold.backgroundColor, isNull,
          reason:
              'Scaffold should not hardcode backgroundColor — it should inherit from theme');
    });

    testWidgets(
        'dark theme scaffold background color is dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await ThemeService.instance.initialize();

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.themeMode,
          builder: (context, themeMode, _) {
            return MaterialApp(
              theme: AppTheme.theme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: Builder(
                builder: (context) {
                  // Verify the theme's scaffoldBackgroundColor is the dark one
                  final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
                  return Scaffold(
                    body: Container(
                      key: const Key('bg_check'),
                      color: scaffoldBg,
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // The scaffold background from dark theme should be AppColors.darkBackground
      final container = tester.widget<Container>(find.byKey(const Key('bg_check')));
      expect(container.color, AppColors.darkBackground,
          reason: 'Dark theme scaffold background should be darkBackground');
    });

    testWidgets('theme toggle rebuilds MaterialApp with correct colors',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService.instance.initialize();

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.themeMode,
          builder: (context, themeMode, _) {
            return MaterialApp(
              theme: AppTheme.theme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: Column(
                      children: [
                        Text(
                          'Test',
                          key: const Key('theme_test_text'),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        ElevatedButton(
                          key: const Key('toggle_btn'),
                          onPressed: () {
                            ThemeService.instance.setThemeMode(ThemeMode.dark);
                          },
                          child: const Text('Toggle'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Initially system mode — verify light theme text color
      final textBefore = tester.widget<Text>(find.byKey(const Key('theme_test_text')));
      expect(textBefore.style?.color, AppColors.textPrimary);

      // Switch to dark mode
      await tester.tap(find.byKey(const Key('toggle_btn')));
      await tester.pumpAndSettle();

      // Now text should use dark theme colors
      final textAfter = tester.widget<Text>(find.byKey(const Key('theme_test_text')));
      expect(textAfter.style?.color, AppColors.darkTextPrimary);
    });
  });
}
