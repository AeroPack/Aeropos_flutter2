import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SseClient {
  HttpClient? _httpClient;
  StreamSubscription<String>? _lineSubscription;
  bool _disposed = false;
  int _reconnectDelay = 2;
  Timer? _reconnectTimer;

  static const int _maxReconnectDelay = 60;

  Future<void> connect({
    required String url,
    required String token,
    required String companyId,
    required void Function() onEvent,
    required void Function(String) onLog,
  }) async {
    if (_disposed) return;
    _cancel();

    try {
      _httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);

      final uri = Uri.parse(url);
      final request = await _httpClient!.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('X-Company-Id', companyId);
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      final response = await request.close();

      if (response.statusCode != 200) {
        onLog('[SSE] HTTP ${response.statusCode} — will retry');
        _scheduleReconnect(
          url: url,
          token: token,
          companyId: companyId,
          onEvent: onEvent,
          onLog: onLog,
        );
        return;
      }

      _reconnectDelay = 2;
      onLog('[SSE] Connected');

      _lineSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data:')) {
            final payload = line.substring(5).trim();
            onLog('[SSE] event=$payload');
            if (payload == 'ping') onEvent();
          }
        },
        onError: (Object e) {
          onLog('[SSE] error: $e');
          _scheduleReconnect(
            url: url,
            token: token,
            companyId: companyId,
            onEvent: onEvent,
            onLog: onLog,
          );
        },
        onDone: () {
          if (!_disposed) {
            onLog('[SSE] stream ended — reconnecting');
            _scheduleReconnect(
              url: url,
              token: token,
              companyId: companyId,
              onEvent: onEvent,
              onLog: onLog,
            );
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      onLog('[SSE] connect failed: $e');
      _scheduleReconnect(
        url: url,
        token: token,
        companyId: companyId,
        onEvent: onEvent,
        onLog: onLog,
      );
    }
  }

  void _scheduleReconnect({
    required String url,
    required String token,
    required String companyId,
    required void Function() onEvent,
    required void Function(String) onLog,
  }) {
    if (_disposed) return;
    _cancel();
    onLog('[SSE] retry in ${_reconnectDelay}s');
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(2, _maxReconnectDelay);
      connect(
        url: url,
        token: token,
        companyId: companyId,
        onEvent: onEvent,
        onLog: onLog,
      );
    });
  }

  void _cancel() {
    _lineSubscription?.cancel();
    _lineSubscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void disconnect() {
    _disposed = true;
    _cancel();
  }

  // Call before re-connecting after a deliberate disconnect (e.g., re-login).
  void resetForReconnect() {
    _disposed = false;
    _reconnectDelay = 2;
  }
}
