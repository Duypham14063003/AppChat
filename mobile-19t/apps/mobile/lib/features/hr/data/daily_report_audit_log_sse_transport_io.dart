import 'dart:convert';
import 'dart:io';

import 'daily_report_audit_log_sse_transport_base.dart';

Future<DailyReportAuditLogSseTransport> openDailyReportAuditLogSseTransport({
  required Uri uri,
  required Map<String, String> headers,
}) async {
  final client = HttpClient();
  final request = await client.getUrl(uri);
  headers.forEach(request.headers.set);
  final response = await request.close();

  if (response.statusCode != HttpStatus.ok) {
    final body = await utf8.decoder.bind(response).join();
    client.close(force: true);
    throw DailyReportAuditLogSseTransportException(
      body.isNotEmpty ? body : 'Failed to open SSE stream',
      statusCode: response.statusCode,
    );
  }

  return _IoDailyReportAuditLogSseTransport(
    client: client,
    response: response,
  );
}

class _IoDailyReportAuditLogSseTransport
    implements DailyReportAuditLogSseTransport {
  _IoDailyReportAuditLogSseTransport({
    required HttpClient client,
    required HttpClientResponse response,
  })  : _client = client,
        _stream = utf8.decoder.bind(response).asBroadcastStream();

  final HttpClient _client;
  final Stream<String> _stream;

  @override
  Stream<String> get stream => _stream;

  @override
  Future<void> close() async {
    _client.close(force: true);
  }
}
