import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bikhari_khata/main.dart';

void main() {
  testWidgets('App launches and shows the activity screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SplitKhataApp());
    await tester.pumpAndSettle();

    expect(find.text('Split Khata'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Groups'), findsWidgets);
    expect(find.text('Total spent'), findsOneWidget);
  });
}
