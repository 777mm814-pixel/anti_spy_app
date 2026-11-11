import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/app_settings.dart';
import 'ui/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // إصلاح الخطأ الأول: إضافة المعاملات الإلزامية للحزمة
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'anti_spy_channel',
      channelName: 'Intruder Shield',
      channelDescription: 'Foreground service for Intruder Shield',
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppSettings>().themeMode;
    
    return MaterialApp(
      title: 'Intruder Shield',
      // إصلاح الخطأ الثاني: استخدام ThemeData مباشرة بدلاً من light() و dark()
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.grey,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
