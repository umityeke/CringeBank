import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../utils/platform_info.dart';

class TraceHttpResponse {
  TraceHttpResponse({
    required this.response,
    required this.elapsed,
    required this.traceId,
    required this.spanId,
    required this.operation,
    required this.startedAt,
  });

  final http.Response response;
  final Duration elapsed;
  final String traceId;
  final String spanId;
  final String? operation;
  final DateTime startedAt;

  bool get isSuccess =>
      response.statusCode >= 200 && response.statusCode < 300;

  Map<String, dynamic>? decodeJson() {
    if (response.body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, dynamic value) => MapEntry('$key', value),
        );
      }
    } catch (_) {
      // ignore parse errors; caller can work with raw body
    }
    return null;
  }
}

class TraceHttpClient {
  TraceHttpClient({
    http.Client? httpClient,
    Duration defaultTimeout = const Duration(seconds: 10),
    Random? random,
  })  : _client = httpClient ?? http.Client(),
        _defaultTimeout = defaultTimeout,
        _random = random ?? Random();

  static final TraceHttpClient shared = TraceHttpClient();

  final http.Client _client;
  final Duration _defaultTimeout;
  final Random _random;

  FirebaseCrashlytics? get _crashlytics =>
      PlatformInfo.supportsCrashlytics ? FirebaseCrashlytics.instance : null;

  Future<TraceHttpResponse> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? jsonBody,
    String? operation,
    Duration? timeout,
  }) async {
    final body = jsonBody == null ? null : jsonEncode(jsonBody);
    final effectiveHeaders = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...?headers,
    };
    return send(
      'POST',
      uri,
      headers: effectiveHeaders,
      body: body,
      operation: operation,
      timeout: timeout,
    );
  }

  Future<TraceHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    String? operation,
    Duration? timeout,
  }) async {
    final traceId = _generateId(16);
    final spanId = _generateId(8);
    final startedAt = DateTime.now().toUtc();
    final traceparent = '00-$traceId-$spanId-01';

    final effectiveHeaders = <String, String>{...?headers};
    effectiveHeaders.putIfAbsent('traceparent', () => traceparent);
    effectiveHeaders.putIfAbsent('x-client-trace-id', () => traceId);
    effectiveHeaders.putIfAbsent('x-request-id', () => spanId);
    effectiveHeaders.putIfAbsent(
      'x-request-start',
      () => 't=${startedAt.microsecondsSinceEpoch ~/ 1000}',
    );
    if (operation != null && operation.isNotEmpty) {
      effectiveHeaders.putIfAbsent('x-trace-operation', () => operation);
    }

    final request = http.Request(method, uri)
      ..headers.addAll(effectiveHeaders);

    if (encoding != null) {
      request.encoding = encoding;
    }

    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map || body is Iterable) {
        request.body = jsonEncode(body);
      } else {
        request.body = body.toString();
      }
    }

    final stopwatch = Stopwatch()..start();
    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(timeout ?? _defaultTimeout);
    } catch (error, stackTrace) {
      stopwatch.stop();
      _logFailure(
        uri: uri,
        method: method,
        elapsed: stopwatch.elapsed,
        error: error,
        stackTrace: stackTrace,
        traceId: traceId,
        spanId: spanId,
        operation: operation,
      );
      rethrow;
    }

    final response = await http.Response.fromStream(streamed);
    stopwatch.stop();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _logSuccess(
        uri: uri,
        method: method,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
        traceId: traceId,
        spanId: spanId,
        operation: operation,
      );
    } else {
      _logFailure(
        uri: uri,
        method: method,
        elapsed: stopwatch.elapsed,
        error: Exception('HTTP ${response.statusCode}'),
        stackTrace: null,
        traceId: traceId,
        spanId: spanId,
        operation: operation,
        statusCode: response.statusCode,
      );
    }

    return TraceHttpResponse(
      response: response,
      elapsed: stopwatch.elapsed,
      traceId: traceId,
      spanId: spanId,
      operation: operation,
      startedAt: startedAt,
    );
  }

  void close() => _client.close();

  String _generateId(int lengthBytes) {
    final bytes = List<int>.generate(lengthBytes, (_) => _random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _logSuccess({
    required Uri uri,
    required String method,
    required Duration elapsed,
    required int statusCode,
    required String traceId,
    required String spanId,
    String? operation,
  }) {
    final payload = jsonEncode(<String, Object?>{
      'method': method,
      'uri': uri.toString(),
      'statusCode': statusCode,
      'elapsedMs': elapsed.inMilliseconds,
      'traceId': traceId,
      'spanId': spanId,
      if (operation != null) 'operation': operation,
    });

    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      unawaited(crashlytics.log('trace_http success $payload'));
      unawaited(crashlytics.setCustomKey('trace_http_last_ms', elapsed.inMilliseconds));
    } else {
      debugPrint('trace_http success $payload');
    }

    _addSentryBreadcrumb(
      message: '$method ${uri.toString()} $statusCode',
      data: {
        'elapsedMs': elapsed.inMilliseconds,
        'traceId': traceId,
        if (operation != null) 'operation': operation,
      },
      level: SentryLevel.info,
    );
  }

  void _logFailure({
    required Uri uri,
    required String method,
    required Duration elapsed,
    required Object error,
    required String traceId,
    required String spanId,
    String? operation,
    StackTrace? stackTrace,
    int? statusCode,
  }) {
    final payload = jsonEncode(<String, Object?>{
      'method': method,
      'uri': uri.toString(),
      'elapsedMs': elapsed.inMilliseconds,
      'traceId': traceId,
      'spanId': spanId,
      if (operation != null) 'operation': operation,
      if (statusCode != null) 'statusCode': statusCode,
      'error': error.toString(),
    });

    final crashlytics = _crashlytics;
    if (crashlytics != null) {
      unawaited(crashlytics.log('trace_http failure $payload'));
      unawaited(
        crashlytics.recordError(
          error,
          stackTrace,
          reason: 'trace_http_failure',
          fatal: false,
        ),
      );
    } else {
      debugPrint('trace_http failure $payload');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }

    _addSentryBreadcrumb(
      message: '$method ${uri.toString()} failure',
      data: {
        'elapsedMs': elapsed.inMilliseconds,
        'traceId': traceId,
        if (statusCode != null) 'statusCode': statusCode,
        if (operation != null) 'operation': operation,
      },
      level: SentryLevel.error,
    );
  }

  void _addSentryBreadcrumb({
    required String message,
    Map<String, Object?>? data,
    required SentryLevel level,
  }) {
    try {
      if (!Sentry.isEnabled) {
        return;
      }
    } catch (_) {
      return;
    }

    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'http',
          message: message,
          data: data,
          level: level,
        ),
      );
    } catch (_) {
      // Ignore Sentry errors to keep client resilient
    }
  }
}
