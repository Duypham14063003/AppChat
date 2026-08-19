import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../models/poc_models.dart';

String pocStatusLabel(String status) => switch (status) {
  'unassigned' => 'Chờ phân công',
  'assigned' => 'Đã phân công',
  'in_progress' => 'Đang làm',
  'ready' => 'Sẵn sàng demo',
  'demonstrated' => 'Đã demo',
  'cancelled' => 'Đã hủy',
  _ => status,
};

String pocProductLabel(String type) => switch (type) {
  'website' => 'Website',
  'web_app' => 'Web app',
  'validation' => 'Demo / Validation',
  _ => type,
};

Color pocStatusColor(PocRecord poc, AppThemePalette palette) {
  if (poc.overdue) return AppColors.danger;
  return switch (poc.status) {
    'ready' => AppColors.online,
    'demonstrated' => palette.primary,
    'cancelled' => palette.textHint,
    'unassigned' => AppColors.warning,
    _ => AppColors.info,
  };
}

class PocStatusBadge extends StatelessWidget {
  const PocStatusBadge({super.key, required this.poc});
  final PocRecord poc;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final color = pocStatusColor(poc, palette);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        poc.overdue ? 'Quá hạn' : pocStatusLabel(poc.status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PocListCard extends StatelessWidget {
  const PocListCard({super.key, required this.poc, required this.onTap});
  final PocRecord poc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.surfaceVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poc.code ?? 'Chưa sinh mã PoC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PocStatusBadge(poc: poc),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                poc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                poc.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _Meta(
                    icon: Icons.support_agent_outlined,
                    text: poc.saleUser?.name ?? 'Chưa rõ Sale',
                  ),
                  _Meta(
                    icon: Icons.person_outline,
                    text: poc.developerUser?.name ?? 'Chưa có Dev',
                  ),
                  if (poc.estimatedHours != null)
                    _Meta(
                      icon: Icons.schedule_outlined,
                      text: '${poc.estimatedHours!.toStringAsFixed(1)} giờ',
                    ),
                  _Meta(
                    icon: Icons.event_outlined,
                    text: DateFormat('HH:mm dd/MM/yyyy').format(poc.demoAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
