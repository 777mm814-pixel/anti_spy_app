import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/app_settings.dart';
import 'ui/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // عرض أي خطأ في بناء الواجهة بدلاً من شاشة رمادية
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'حدث خطأ غير متوقع:\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };

  // التقاط الأخطاء غير المتزامنة ومنع إغلاق التطبيق
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error');
    return true;
  };

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // تأجيل تهيئة الخدمة حتى تصبح الواجهة جاهزة فعلاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeInitForegroundTask();
    });
  }

  Future<void> _safeInitForegroundTask() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'anti_spy_channel',
          channelName: 'Intruder Shield',
          channelDescription: 'Foreground service for Intruder Shield',
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      debugPrint('ForegroundTask initialized');
    } catch (e) {
      debugPrint('ForegroundTask init failed (non-fatal): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppSettings>().themeMode;

    return MaterialApp(
      title: 'Intruder Shield',
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
