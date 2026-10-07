import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bikhari_khata/main.dart';

void main() {
  testWidgets('Splash → onboarding → sign-in flow', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SplitKhataApp());
    await tester.pump(); // let the splash entrance animation start
    await tester.pump(const Duration(seconds: 3)); // splash delay elapses
    await tester.pumpAndSettle();

    // First launch: onboarding page 1.
    expect(find.text('Add & Split Expenses'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Know Who Owes Whom'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Groups, Trips & Settle Up'), findsOneWidget);

    await tester.tap(find.text('Get started 🎉'));
    await tester.pumpAndSettle();

    // Onboarded: the auth screen appears.
    expect(find.text('Split Khata'), findsOneWidget);
    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('Returning user skips onboarding', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'split_onboarded': true});

    await tester.pumpWidget(const SplitKhataApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Add & Split Expenses'), findsNothing);
    expect(find.text('Welcome back 👋'), findsOneWidget);
  });
}
