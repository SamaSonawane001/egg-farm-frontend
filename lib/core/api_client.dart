import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'config.dart';
import 'http_client.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  final int? retryAfterSeconds;
  ApiException(this.message, [this.status, this.code, this.retryAfterSeconds]);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  final ValueNotifier<int> mutationVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> farmVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> cacheVersion = ValueNotifier<int>(0);
  final http.Client _client = createApiHttpClient();
  final Map<String, _CachedResponse> _getCache = {};
  final Map<String, Future<dynamic>> _inFlightGets = {};
  static const _cacheLifetime = Duration(seconds: 20);
  static const _maxCacheEntries = 128;
  int _cacheEpoch = 0;

  String? _token;
  String? get token => _token;
  set token(String? value) {
    if (_token == value) return;
    _token = value;
    invalidateCache();
  }

  String? _farmId;
  String? get farmId => _farmId;
  set farmId(String? value) {
    if (_farmId == value) return;
    _farmId = value;
    farmVersion.value++;
  }

  VoidCallback? onUnauthorized;
  Future<bool> Function()? onFarmRequired;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (!kIsWeb) 'Connection': 'keep-alive',
        if (token != null) 'Authorization': 'Bearer $token',
        if (_farmId != null) 'X-Farm-Id': _farmId!,
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$kApiBase$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _get(path, query);

  Future<dynamic> _get(String path, Map<String, String>? query) async {
    final uri = _uri(path, query);
    final key = _getCacheKey(uri, query);
    final cached = _getCache[key];
    if (cached != null) {
      if (DateTime.now().isAfter(cached.freshUntil)) {
        unawaited(_fetchGet(key, uri).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Background refresh failed for $path: $error');
          },
        ));
      }
      return _copyJson(cached.value);
    }
    return _copyJson(await _fetchGet(key, uri));
  }

  String _getCacheKey(Uri uri, Map<String, String>? query) {
    final sortedQuery = Map<String, String>.fromEntries(
      (query ?? const <String, String>{}).entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final canonicalUri = query == null
        ? uri.toString()
        : uri.replace(queryParameters: sortedQuery).toString();
    return '${_token ?? ''}|${_farmId ?? ''}|$canonicalUri';
  }

  Future<dynamic> _fetchGet(String key, Uri uri) {
    final existing = _inFlightGets[key];
    if (existing != null) return existing;
    final epoch = _cacheEpoch;
    late final Future<dynamic> request;
    request = _send(() => _client.get(uri, headers: _headers)).then((value) {
      if (epoch == _cacheEpoch) _storeGetResponse(key, value);
      return value;
    }).whenComplete(() {
      if (identical(_inFlightGets[key], request)) {
        _inFlightGets.remove(key);
      }
    });
    _inFlightGets[key] = request;
    return request;
  }

  void _storeGetResponse(String key, dynamic value) {
    _getCache.remove(key);
    _getCache[key] = _CachedResponse(
      _copyJson(value),
      DateTime.now().add(_cacheLifetime),
    );
    while (_getCache.length > _maxCacheEntries) {
      _getCache.remove(_getCache.keys.first);
    }
    cacheVersion.value++;
  }

  dynamic _copyJson(dynamic value) => jsonDecode(jsonEncode(value));

  void invalidateCache() {
    _cacheEpoch++;
    _getCache.clear();
    _inFlightGets.clear();
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) => _mutate(() =>
      _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> put(String path, Map<String, dynamic> body) => _mutate(
      () => _client.put(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> patch(String path, Map<String, dynamic> body) => _mutate(() =>
      _client.patch(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> delete(String path) =>
      _mutate(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> _mutate(Future<http.Response> Function() call,
      {String? fallbackError,
      Duration timeout = const Duration(seconds: 10)}) async {
    dynamic result;
    try {
      result =
          await _send(call, fallbackError: fallbackError, timeout: timeout);
    } on ApiException catch (error) {
      if (error.code != 'FARM_REQUIRED' || onFarmRequired == null) rethrow;
      if (!await onFarmRequired!()) rethrow;
      result =
          await _send(call, fallbackError: fallbackError, timeout: timeout);
    }
    invalidateCache();
    mutationVersion.value++;
    return result;
  }

  Future<dynamic> multipart(
      String method, String path, Map<String, String> fields,
      {Uint8List? fileBytes,
      String? fileName,
      String fileField = 'avatar',
      MediaType? contentType}) {
    return _mutate(() async {
      final req = http.MultipartRequest(method, _uri(path));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (_farmId != null) req.headers['X-Farm-Id'] = _farmId!;
      req.fields.addAll(fields);
      if (fileBytes != null) {
        req.files.add(http.MultipartFile.fromBytes(fileField, fileBytes,
            filename: fileName ?? 'avatar.jpg', contentType: contentType));
      }
      return http.Response.fromStream(await req.send());
    }, fallbackError: 'Upload failed', timeout: const Duration(seconds: 60));
  }

  Future<dynamic> _send(Future<http.Response> Function() call,
      {String? fallbackError,
      Duration timeout = const Duration(seconds: 10)}) async {
    http.Response r;
    try {
      r = await call().timeout(timeout);
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your internet / API address.');
    }
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (body is Map && body.containsKey('pagination')) {
        return {'data': body['data'], 'pagination': body['pagination']};
      }
      return body is Map && body.containsKey('data') ? body['data'] : body;
    }
    if (r.statusCode == 401 && token != null) onUnauthorized?.call();
    final retryAfterSeconds = body is Map
        ? int.tryParse('${body['retry_after_seconds'] ?? ''}')
        : null;
    throw ApiException(
        body is Map && body['message'] != null
            ? body['message'].toString()
            : body is Map && body['error'] != null
                ? body['error'].toString()
                : '${fallbackError ?? 'Request failed'} (${r.statusCode})',
        r.statusCode,
        body is Map && body['code'] != null ? body['code'].toString() : null,
        retryAfterSeconds);
  }
}

class _CachedResponse {
  final dynamic value;
  final DateTime freshUntil;

  const _CachedResponse(this.value, this.freshUntil);
}
