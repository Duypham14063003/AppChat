import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/theme_color_presets.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/vietqr.dart';

final _paymentQrImageProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, url) async {
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data ?? const []);
    });

String? _paymentQrApiPath(String rawUrl) {
  const apiPrefix = '/api/v1';
  final path = rawUrl.startsWith('$apiPrefix/hr/employees/')
      ? rawUrl.substring(apiPrefix.length)
      : rawUrl;
  return path.startsWith('/hr/employees/') ? path : null;
}

class EmployeePaymentQr extends ConsumerWidget {
  const EmployeePaymentQr({
    super.key,
    required this.bankCode,
    required this.accountNumber,
    this.uploadedImageUrl,
    this.source,
    this.compact = false,
  });

  final String? bankCode;
  final String? accountNumber;
  final String? uploadedImageUrl;
  final String? source;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final useUploaded =
        source == 'uploaded' && uploadedImageUrl?.isNotEmpty == true;
    Widget content;
    String label;
    if (useUploaded) {
      final raw = uploadedImageUrl!;
      final apiPath = _paymentQrApiPath(raw);
      label = 'QR đã tải lên';
      content = apiPath != null
          ? ref
                .watch(_paymentQrImageProvider(apiPath))
                .when(
                  loading: () => const SizedBox.square(
                    dimension: 48,
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const _QrMessage('Không tải được ảnh QR'),
                  data: (bytes) => Image.memory(
                    bytes,
                    width: compact ? 150 : 220,
                    height: compact ? 150 : 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const _QrMessage('Không tải được ảnh QR'),
                  ),
                )
          : const _QrMessage('Ảnh QR cũ cần được tải lại');
    } else {
      try {
        final payload = const VietQrPayloadBuilder().build(
          bankCode: bankCode ?? '',
          accountNumber: accountNumber ?? '',
        );
        label = 'VietQR tự động';
        content = QrImageView(
          data: payload,
          version: QrVersions.auto,
          size: compact ? 150 : 220,
          backgroundColor: Colors.white,
        );
      } on ArgumentError {
        label = 'Chưa thể tạo VietQR';
        content = const _QrMessage('Chọn ngân hàng và nhập số tài khoản');
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(label),
          content: SizedBox.square(
            dimension: 320,
            child: FittedBox(child: content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.card.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.surfaceVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              'Nhấn để phóng to',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrMessage extends StatelessWidget {
  const _QrMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 180,
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );
}
