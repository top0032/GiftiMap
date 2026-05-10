import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../features/map/data/services/geofence_task_handler.dart';

/// 포그라운드 서비스의 진입점(Entry Point)입니다.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}
