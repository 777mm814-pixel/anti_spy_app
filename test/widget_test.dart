import 'package:flutter_test/flutter_test.dart';
import 'package:intruder_shield/main.dart';

void main() {
  testWidgets('Intruder Shield app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const IntruderShieldApp());
    expect(find.text('Intruder Shield'), findsOneWidget);
  });
}
