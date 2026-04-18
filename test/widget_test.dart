import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:hive_flutter_v1/main.dart';

void main() {
  testWidgets('HIVE flows from splash to onboarding to permission', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const HiveApp());

    expect(find.text('HIVE'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Introduction'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy & Access'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & Access'), findsOneWidget);
    expect(find.text('Your photos stay private.'), findsOneWidget);
  });
}
