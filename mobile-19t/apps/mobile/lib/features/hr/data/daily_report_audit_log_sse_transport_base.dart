abstract class DailyReportAuditLogSseTransport {
  Stream<String> get stream;
  Future<void> close();
}

class DailyReportAuditLogSseTransportException implements Exception {
  const DailyReportAuditLogSseTransportException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) return message;
    return '$message (status: $statusCode)';
  }
}
