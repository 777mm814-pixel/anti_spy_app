import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'models/app_settings.dart';
import 'ui/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'anti_spy_channel',
      channelName: 'Intruder Shield',
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
      theme: ThemeData.light(useMaterial3: true, colorSchemeSeed: Colors.grey),
      darkTheme: ThemeData.dark(useMaterial3: true, colorSchemeSeed: Colors.teal),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
