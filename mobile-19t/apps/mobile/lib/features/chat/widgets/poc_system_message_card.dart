import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';

bool isSupportedPocSystemMetadata(Map<String, dynamic>? metadata) {
  final kind = metadata?['kind']?.toString();
  return metadata?['schema_version'] == 1 &&
      kind != null &&
      kind.startsWith('poc_') &&
      (kind == 'poc_weekly_summary' || metadata?['poc_id'] != null);
}

class PocSystemMessageCard extends StatelessWidget {
  const PocSystemMessageCard({
    super.key,
    required this.kind,
    required this.metadata,
    required this.onOpen,
  });

  final String kind;
  final Map<String, dynamic> metadata;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isWeekly = kind == 'poc_weekly_summary';
    final code = metadata['code']?.toString();
    final pocTitle = metadata['title']?.toString();
    final customer = metadata['customer_name']?.toString();
    final demoAt = DateTime.tryParse(
      metadata['demo_at']?.toString() ?? '',
    )?.toLocal();
    final changes = metadata['changes'] is Map
        ? (metadata['changes'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final demoChange = changes['demo_at'] is Map
        ? (changes['demo_at'] as Map).cast<String, dynamic>()
        : null;
    final oldDemo = DateTime.tryParse(
      demoChange?['previous']?.toString() ?? '',
    )?.toLocal();
    final newDemo = DateTime.tryParse(
      demoChange?['current']?.toString() ?? '',
    )?.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.surfaceVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isWeekly
                        ? Icons.summarize_outlined
                        : Icons.science_outlined,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      pocSystemTitle(kind),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isWeekly && (code != null || pocTitle != null)) ...[
                const SizedBox(height: 8),
                Text(
                  [code, pocTitle].whereType<String>().join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ],
              if (customer != null) ...[
                const SizedBox(height: 3),
                Text(
                  customer,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
              if (oldDemo != null && newDemo != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${formatPocChatTime(oldDemo)} → ${formatPocChatTime(newDemo)}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ] else if (demoAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Demo: ${formatPocChatTime(demoAt)}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onOpen(pocSystemDeepLink(metadata)),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(isWeekly ? 'Xem báo cáo' : 'Mở PoC'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String pocSystemDeepLink(Map<String, dynamic> metadata) {
  final kind = metadata['kind']?.toString();
  final deepLink = metadata['deep_link']?.toString();
  if (deepLink?.startsWith('/pocs/') == true) return deepLink!;
  if (kind == 'poc_weekly_summary') {
    final week =
        metadata['week']?.toString() ?? metadata['week_start']?.toString();
    return '/pocs/week${week == null ? '' : '?week=${Uri.encodeComponent(week)}'}';
  }
  return '/pocs/${metadata['poc_id']}';
}

String pocSystemTitle(String kind) => switch (kind) {
  'poc_assigned' => 'PoC đã được phân công',
  'poc_reassigned' => 'PoC đã đổi Dev phụ trách',
  'poc_plan_updated' => 'Kế hoạch PoC đã thay đổi',
  'poc_status_in_progress' => 'PoC đã bắt đầu',
  'poc_status_ready' => 'PoC sẵn sàng demo',
  'poc_status_demonstrated' => 'Đã ghi nhận kết quả demo',
  'poc_revision_required' => 'PoC cần chỉnh sửa',
  'poc_status_cancelled' => 'PoC đã hủy',
  'poc_demo_24h' => 'Còn 24 giờ tới lịch demo',
  'poc_demo_30m' => 'Còn 30 phút tới lịch demo',
  'poc_deadline' => 'PoC đến hạn demo',
  'poc_overdue' => 'PoC đã quá hạn',
  'poc_weekly_summary' => 'Tổng hợp PoC trong tuần',
  _ => 'Cập nhật PoC',
};

String formatPocChatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} '
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
