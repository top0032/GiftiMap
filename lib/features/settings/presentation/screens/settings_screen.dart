import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/notification_settings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('알림 설정', style: TextStyle(color: AppTheme.secondaryNavy, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondaryNavy),
          onPressed: () => context.pop(),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
        error: (error, stack) => Center(child: Text('설정을 불러오지 못했습니다: $error')),
        data: (settings) => SingleChildScrollView(
          child: Column(
            children: [
              _buildToggleSection(context, ref, settings.isEnabled),
              if (settings.isEnabled) ...[
                const Divider(height: 1),
                _buildAlertListSection(context, ref, settings.alerts),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSection(BuildContext context, WidgetRef ref, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '기프티콘 만료 알림',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
              ),
              SizedBox(height: 4),
              Text(
                '유효기간이 임박하면 알림을 보냅니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          Switch.adaptive(
            value: isEnabled,
            activeColor: AppTheme.primaryTeal,
            onChanged: (value) => ref.read(settingsControllerProvider.notifier).toggleEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertListSection(BuildContext context, WidgetRef ref, List<AlertConfig> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '설정된 알림 목록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
              ),
              TextButton.icon(
                onPressed: () => _addUnifiedAlert(context, ref, alerts),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppTheme.primaryTeal),
                label: const Text('알림 추가', style: TextStyle(color: AppTheme.primaryTeal)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTeal),
              ),
            ],
          ),
        ),
        if (alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: Text('설정된 알림이 없습니다.\n새 알림을 추가해 보세요!', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final dayLabel = alert.daysBefore == 0 ? '당일' : '${alert.daysBefore}일 전';
              final timeLabel = '${alert.hour >= 12 ? '오후' : '오전'} ${(alert.hour % 12 == 0 ? 12 : alert.hour % 12).toString().padLeft(2, '0')}:${alert.minute.toString().padLeft(2, '0')}';
              
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryTeal, size: 20),
                ),
                title: Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy)),
                subtitle: Text(timeLabel),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => ref.read(settingsControllerProvider.notifier).removeAlert(alert),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _addUnifiedAlert(BuildContext context, WidgetRef ref, List<AlertConfig> currentAlerts) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '알림을 받을 날짜 선택',
      cancelText: '취소',
      confirmText: '다음 (시간 선택)',
    );

    if (pickedDate == null) return;

    final daysBefore = pickedDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (!context.mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: '${daysBefore == 0 ? '당일' : '$daysBefore일 전'} 알림 시간 설정',
      cancelText: '취소',
      confirmText: '완료',
      hourLabelText: '시',
      minuteLabelText: '분',
    );

    if (pickedTime == null) return;

    await ref.read(settingsControllerProvider.notifier).addAlert(
      AlertConfig(
        daysBefore: daysBefore,
        hour: pickedTime.hour,
        minute: pickedTime.minute,
      ),
    );
  }
}
