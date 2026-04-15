import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agro_pickgh/main.dart';

void main() {
  testWidgets('app shell can render', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AgroPickupApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
