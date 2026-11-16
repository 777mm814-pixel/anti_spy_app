import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:anti_spy_app/main.dart';
import 'package:anti_spy_app/models/app_settings.dart';

void main() {
  testWidgets('App renders Intruder Shield title', (WidgetTester tester) async {
    // بناء الواجهة مع المزود المطلوب
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: const MyApp(),
      ),
    );

    // التحقق من ظهور عنوان التطبيق
    expect(find.text('Intruder Shield'), findsOneWidget);
  });
}
