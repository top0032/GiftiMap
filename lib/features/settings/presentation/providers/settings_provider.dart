import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/notification_settings.dart';
import '../../../gifticon/data/repositories/gifticon_repository.dart';
import '../../../gifticon/data/services/expiration_notification_service.dart';
import 'package:giftimap/features/auth/presentation/providers/auth_provider.dart';

part 'settings_provider.g.dart';

@riverpod
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository();
}

@riverpod
class SettingsController extends _$SettingsController {
  @override
  FutureOr<NotificationSettings> build() async {
    // 인증 상태가 변경되면 설정을 새로 불러옴
    ref.watch(authStateProvider);
    final repo = ref.watch(settingsRepositoryProvider);
    return await repo.getNotificationSettings();
  }

  Future<void> addAlert(AlertConfig config) async {
    final repo = ref.read(settingsRepositoryProvider);
    final currentSettings = state.value ?? NotificationSettings.defaultSettings();
    
    // 중복 체크 (일수와 시간이 모두 같은 경우)
    if (currentSettings.alerts.any((a) => a.daysBefore == config.daysBefore && a.hour == config.hour && a.minute == config.minute)) {
      return;
    }

    final newAlerts = List<AlertConfig>.from(currentSettings.alerts)..add(config);
    // 일수 순으로 정렬
    newAlerts.sort((a, b) => a.daysBefore.compareTo(b.daysBefore));
    
    final newSettings = currentSettings.copyWith(alerts: newAlerts);
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.saveNotificationSettings(newSettings);
      _rescheduleAllNotifications();
      return newSettings;
    });
  }

  Future<void> removeAlert(AlertConfig config) async {
    final repo = ref.read(settingsRepositoryProvider);
    final currentSettings = state.value ?? NotificationSettings.defaultSettings();
    
    final newAlerts = currentSettings.alerts.where((a) => 
      !(a.daysBefore == config.daysBefore && a.hour == config.hour && a.minute == config.minute)
    ).toList();
    
    final newSettings = currentSettings.copyWith(alerts: newAlerts);
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.saveNotificationSettings(newSettings);
      _rescheduleAllNotifications();
      return newSettings;
    });
  }

  Future<void> toggleEnabled(bool enabled) async {
    final repo = ref.read(settingsRepositoryProvider);
    final currentSettings = state.value ?? NotificationSettings.defaultSettings();
    final newSettings = currentSettings.copyWith(isEnabled: enabled);
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.saveNotificationSettings(newSettings);
      
      if (!enabled) {
        // 알림 비활성화 시 모든 예약된 알림 취소
        _cancelAllNotifications();
      } else {
        // 다시 활성화 시 재스케줄링
        _rescheduleAllNotifications();
      }
      
      return newSettings;
    });
  }

  Future<void> updateGeofenceRadius(double radius) async {
    final repo = ref.read(settingsRepositoryProvider);
    final currentSettings = state.value ?? NotificationSettings.defaultSettings();
    final newSettings = currentSettings.copyWith(geofenceRadius: radius);
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repo.saveNotificationSettings(newSettings);
      // 지오펜싱 반경 변경 시 MapHomeScreen에서 setupGeofences를 다시 호출하도록 유도하거나, 
      // 여기서 직접 서비스 트리거가 필요할 수 있으나 UI에서 반응형으로 처리하도록 설계함
      return newSettings;
    });
  }

  /// 모든 기프티콘의 알림을 취소하고 다시 예약합니다.
  Future<void> _rescheduleAllNotifications() async {
    final gifticonRepo = ref.read(gifticonRepositoryProvider);
    final notificationService = ExpirationNotificationService();
    
    final gifticons = await gifticonRepo.getGifticons();
    
    // 기존 모든 알림 취소 (기본적인 관리 차원)
    for (var gifticon in gifticons) {
      await notificationService.cancelExpirationNotifications(gifticon.id);
      
      // 설정이 활성화되어 있는 경우에만 다시 예약
      if (state.value?.isEnabled ?? true) {
        await notificationService.scheduleExpirationNotifications(gifticon);
      }
    }
  }

  Future<void> _cancelAllNotifications() async {
    final gifticonRepo = ref.read(gifticonRepositoryProvider);
    final notificationService = ExpirationNotificationService();
    
    final gifticons = await gifticonRepo.getGifticons();
    for (var gifticon in gifticons) {
      await notificationService.cancelExpirationNotifications(gifticon.id);
    }
  }
}
