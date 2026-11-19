import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/app_settings.dart';
import 'models/locale_provider.dart';
import 'ui/main_screen.dart';

// دالة top-level مطلوبة لبدء الخدمة من الواجهة
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(IntruderTaskHandler());
}

class IntruderTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // تهيئة الكاميرا والكشف هنا عند بدء الخدمة
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // منطق الكشف عن المتطفل الدوري
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // تنظيف الموارد عند إيقاف الخدمة
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'intruder_service',
      channelName: 'Intruder Shield Service',
      channelDescription: 'Monitors for intruders',
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000),
      autoRunOnBoot: true,
      allowWakeLock: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppSettings>().themeMode;
    final locale = context.watch<LocaleProvider>().locale;

    return MaterialApp(
      title: 'Intruder Shield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.grey),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainScreen(),
    );
  }
}
