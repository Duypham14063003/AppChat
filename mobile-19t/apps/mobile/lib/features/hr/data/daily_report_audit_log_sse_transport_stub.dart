import 'daily_report_audit_log_sse_transport_base.dart';

Future<DailyReportAuditLogSseTransport> openDailyReportAuditLogSseTransport({
  required Uri uri,
  required Map<String, String> headers,
}) {
  throw const UnsupportedError('SSE transport is not supported on this platform');
}
