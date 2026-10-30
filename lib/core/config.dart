import 'package:flutter/foundation.dart';

/// Override at run time:  flutter run --dart-define=API_BASE=https://your-api.onrender.com
String _resolveBase() {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:4000';
  return 'http://localhost:4000';
}

final String kApiBase = _resolveBase();
const String kCurrencySymbol = '₹';
const String kDefaultCountryCode = '91'; // used when a customer number has only 10 digits
const int kEggsPerCrate = 30;
