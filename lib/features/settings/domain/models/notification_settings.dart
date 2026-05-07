class AlertConfig {
  final int daysBefore; // 며칠 전인지
  final int hour;       // 시
  final int minute;     // 분

  AlertConfig({
    required this.daysBefore,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
      };

  factory AlertConfig.fromJson(Map<String, dynamic> json) => AlertConfig(
        daysBefore: json['daysBefore'],
        hour: json['hour'],
        minute: json['minute'],
      );
}

class NotificationSettings {
  final List<AlertConfig> alerts; // 통합된 알림 설정 리스트
  final bool isEnabled;          // 알림 전체 사용 여부

  NotificationSettings({
    required this.alerts,
    this.isEnabled = true,
  });

  // 기본값 설정 (당일 9시, 1일 전 9시, 3일 전 9시)
  factory NotificationSettings.defaultSettings() {
    return NotificationSettings(
      alerts: [
        AlertConfig(daysBefore: 0, hour: 9, minute: 0),
        AlertConfig(daysBefore: 1, hour: 9, minute: 0),
        AlertConfig(daysBefore: 3, hour: 9, minute: 0),
      ],
      isEnabled: true,
    );
  }

  NotificationSettings copyWith({
    List<AlertConfig>? alerts,
    bool? isEnabled,
  }) {
    return NotificationSettings(
      alerts: alerts ?? this.alerts,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alerts': alerts.map((e) => e.toJson()).toList(),
      'isEnabled': isEnabled,
    };
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      alerts: (json['alerts'] as List? ?? [])
          .map((e) => AlertConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      isEnabled: json['isEnabled'] ?? true,
    );
  }
}
