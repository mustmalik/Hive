import 'package:flutter_test/flutter_test.dart';

import 'package:hive_flutter_v1/main.dart';

void main() {
  testWidgets('HIVE launches into the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HiveApp());

    expect(find.text('HIVE'), findsOneWidget);
    expect(
      find.text(
        'Organize your gallery into smart cells without changing your Apple Photos library.',
      ),
      findsOneWidget,
    );
  });
}
