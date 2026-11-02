import 'dart:io';

import 'package:http/io_client.dart';

IOClient createApiHttpClient() {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 30);
  return IOClient(client);
}
