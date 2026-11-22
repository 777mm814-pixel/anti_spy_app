import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(KeepAliveTaskHandler());
}

/// هذه الخدمة مسؤولة فقط عن إبقاء التطبيق حياً في الخلفية
/// الكاميرا والكشف يعملان في الواجهة الرئيسية (MainScreen)
class KeepAliveTaskHandler extends TaskHandler {
  Timer? _heartbeat;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (timer) {
      FlutterForegroundTask.sendDataToMain({
        'action': 'SERVICE_ALIVE',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _heartbeat?.cancel();
  }
}
