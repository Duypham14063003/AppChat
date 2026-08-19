import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../chat/providers/chat_providers.dart';
import '../providers/poc_providers.dart';

class PocFormScreen extends ConsumerStatefulWidget {
  const PocFormScreen({
    super.key,
    this.initialConversationId,
    this.sourceMessageId,
  });

  final String? initialConversationId;
  final String? sourceMessageId;

  @override
  ConsumerState<PocFormScreen> createState() => _PocFormScreenState();
}

class _PocFormScreenState extends ConsumerState<PocFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _title = TextEditingController();
  final _requirement = TextEditingController();
  final _links = TextEditingController();
  String _productType = 'validation';
  String _priority = 'normal';
  String? _conversationId;
  late DateTime _demoAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.initialConversationId;
    _demoAt = DateTime.now().add(const Duration(days: 3));
  }

  @override
  void dispose() {
    _customer.dispose();
    _title.dispose();
    _requirement.dispose();
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final conversations = ref.watch(chatListProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Tạo yêu cầu PoC')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _customer,
              decoration: const InputDecoration(
                labelText: 'Khách hàng',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Tên dự án / nội dung demo',
                prefixIcon: Icon(Icons.science_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _requirement,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Yêu cầu cần PoC',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  DropdownButtonFormField<String>(
                    initialValue: _productType,
                    decoration: const InputDecoration(
                      labelText: 'Loại sản phẩm',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'validation',
                        child: Text('Demo / Validation'),
                      ),
                      DropdownMenuItem(
                        value: 'website',
                        child: Text('Website'),
                      ),
                      DropdownMenuItem(
                        value: 'web_app',
                        child: Text('Web app'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _productType = value!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Ưu tiên'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Thấp')),
                      DropdownMenuItem(
                        value: 'normal',
                        child: Text('Bình thường'),
                      ),
                      DropdownMenuItem(value: 'high', child: Text('Cao')),
                      DropdownMenuItem(
                        value: 'urgent',
                        child: Text('Khẩn cấp'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _priority = value!),
                  ),
                ];
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Lịch demo / hạn PoC',
              value: _demoAt,
              onChanged: (value) => setState(() => _demoAt = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _validConversationValue(conversations),
              decoration: const InputDecoration(
                labelText: 'Nhóm làm việc',
                prefixIcon: Icon(Icons.forum_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Không chọn'),
                ),
                ...conversations.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(
                      _conversationName(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _conversationId = value),
            ),
            if (widget.sourceMessageId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Yêu cầu này được liên kết với tin nhắn đã chọn.',
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _links,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Tài liệu tham khảo',
                hintText: 'Mỗi đường dẫn một dòng',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              validator: _validateLinks,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Gửi yêu cầu'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validConversationValue(List<LocalConversation> conversations) {
    if (_conversationId == null) return null;
    return conversations.any((item) => item.id == _conversationId)
        ? _conversationId
        : null;
  }

  String _conversationName(LocalConversation item) =>
      item.name ?? item.otherMemberName ?? 'Cuộc trò chuyện';

  String? _required(String? value) => value == null || value.trim().length < 2
      ? 'Vui lòng nhập ít nhất 2 ký tự'
      : null;

  String? _validateLinks(String? value) {
    for (final link in _referenceLinks(value)) {
      final uri = Uri.tryParse(link);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return 'Đường dẫn không hợp lệ: $link';
      }
    }
    return null;
  }

  List<String> _referenceLinks(String? value) => value
      .toString()
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_demoAt.isAfter(DateTime.now())) {
      _message('Lịch demo phải ở tương lai');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref.read(pocRepositoryProvider).create({
        'customer_name': _customer.text.trim(),
        'title': _title.text.trim(),
        'requirement': _requirement.text.trim(),
        'product_type': _productType,
        'priority': _priority,
        'demo_at': _demoAt.toUtc().toIso8601String(),
        if (_conversationId != null) 'working_conversation_id': _conversationId,
        if (widget.sourceMessageId != null)
          'source_message_id': widget.sourceMessageId,
        'reference_links': _referenceLinks(_links.text),
      });
      ref.invalidate(pocListProvider);
      if (mounted) context.go('/pocs/${created.id}');
    } catch (error) {
      if (mounted) _message('Không thể tạo yêu cầu: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: () async {
      final date = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 730)),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(value),
      );
      if (time == null) return;
      onChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.event_outlined),
      ),
      child: Text(DateFormat('HH:mm, dd/MM/yyyy').format(value)),
    ),
  );
}
