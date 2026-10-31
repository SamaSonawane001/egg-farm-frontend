import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  final ValueNotifier<int> mutationVersion = ValueNotifier<int>(0);

  String? token;
  VoidCallback? onUnauthorized;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$kApiBase$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => http.get(_uri(path, query), headers: _headers));
  Future<dynamic> post(String path, Map<String, dynamic> body) => _mutate(
      () => http.post(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> put(String path, Map<String, dynamic> body) => _mutate(
      () => http.put(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> delete(String path) =>
      _mutate(() => http.delete(_uri(path), headers: _headers));

  Future<dynamic> _mutate(Future<http.Response> Function() call) async {
    final result = await _send(call);
    mutationVersion.value++;
    return result;
  }

  Future<dynamic> multipart(
      String method, String path, Map<String, String> fields,
      {Uint8List? fileBytes, String? fileName, String fileField = 'avatar'}) {
    return _mutate(() async {
      final req = http.MultipartRequest(method, _uri(path));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields.addAll(fields);
      if (fileBytes != null) {
        req.files.add(http.MultipartFile.fromBytes(fileField, fileBytes,
            filename: fileName ?? 'avatar.jpg'));
      }
      return http.Response.fromStream(await req.send());
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check your internet / API address.');
    }
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return body is Map && body.containsKey('data') ? body['data'] : body;
    }
    if (r.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(
        body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Request failed (${r.statusCode})',
        r.statusCode);
  }
}
