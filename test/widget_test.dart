import 'package:flutter_test/flutter_test.dart';
import 'package:anti_spy_app/main.dart';

void main() {
  testWidgets('App renders Intruder Shield title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Intruder Shield'), findsOneWidget);
  });
}
