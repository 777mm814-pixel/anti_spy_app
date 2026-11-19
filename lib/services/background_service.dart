import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(IntruderTaskHandler());
}

class IntruderTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // تهيئة الكاميرا والكشف هنا
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // منطق الكشف الدوري
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // تنظيف الموارد
  }
}
