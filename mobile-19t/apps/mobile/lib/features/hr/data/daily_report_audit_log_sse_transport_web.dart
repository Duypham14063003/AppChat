import 'dart:async';
import 'dart:html' as html;

import 'daily_report_audit_log_sse_transport_base.dart';

Future<DailyReportAuditLogSseTransport> openDailyReportAuditLogSseTransport({
  required Uri uri,
  required Map<String, String> headers,
}) async {
  final request = html.HttpRequest();
  final controller = StreamController<String>.broadcast();
  late final StreamSubscription<html.ProgressEvent> progressSub;
  late final StreamSubscription<html.ProgressEvent> errorSub;
  late final StreamSubscription<html.ProgressEvent> abortSub;
  late final StreamSubscription<html.Event> readyStateSub;
  late final StreamSubscription<html.ProgressEvent> loadEndSub;

  var offset = 0;
  var completed = false;

  void emitPendingChunk() {
    final text = request.responseText ?? '';
    if (offset >= text.length) return;
    controller.add(text.substring(offset));
    offset = text.length;
  }

  void finish() {
    if (completed) return;
    completed = true;
    emitPendingChunk();
    unawaited(controller.close());
  }

  void fail(Object error) {
    if (completed) return;
    completed = true;
    controller.addError(error);
    unawaited(controller.close());
  }

  request
    ..open('GET', uri.toString(), async: true)
    ..responseType = 'text'
    ..withCredentials = false;
  headers.forEach(request.setRequestHeader);

  readyStateSub = request.onReadyStateChange.listen((_) {
    if (request.readyState == html.HttpRequest.HEADERS_RECEIVED &&
        request.status != 200) {
      fail(
        DailyReportAuditLogSseTransportException(
          request.statusText ?? 'Failed to open SSE stream',
          statusCode: request.status,
        ),
      );
      request.abort();
    }
  });
  progressSub = request.onProgress.listen((_) => emitPendingChunk());
  errorSub = request.onError.listen(
    (_) => fail(const DailyReportAuditLogSseTransportException('SSE stream error')),
  );
  abortSub = request.onAbort.listen((_) => finish());
  loadEndSub = request.onLoadEnd.listen((_) {
    if (request.status == 200) {
      finish();
      return;
    }
    fail(
      DailyReportAuditLogSseTransportException(
        request.statusText ?? 'SSE stream closed',
        statusCode: request.status,
      ),
    );
  });

  request.send();

  return _WebDailyReportAuditLogSseTransport(
    request: request,
    stream: controller.stream,
    subscriptions: [
      progressSub,
      errorSub,
      abortSub,
      readyStateSub,
      loadEndSub,
    ],
  );
}

class _WebDailyReportAuditLogSseTransport
    implements DailyReportAuditLogSseTransport {
  _WebDailyReportAuditLogSseTransport({
    required html.HttpRequest request,
    required Stream<String> stream,
    required List<StreamSubscription<dynamic>> subscriptions,
  })  : _request = request,
        _stream = stream,
        _subscriptions = subscriptions;

  final html.HttpRequest _request;
  final Stream<String> _stream;
  final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  Stream<String> get stream => _stream;

  @override
  Future<void> close() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _request.abort();
  }
}
