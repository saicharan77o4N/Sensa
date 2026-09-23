import 'package:flutter_test/flutter_test.dart';

import 'package:sensa/main.dart';

void main() {
  testWidgets('shows the notification capture screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SensaApp());

    expect(find.text('Sensa'), findsOneWidget);
    expect(find.text('No new notifications yet'), findsOneWidget);
  });
}
