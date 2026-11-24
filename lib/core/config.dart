const String _configuredApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: '');
const String _legacyConfiguredApiBase =
    String.fromEnvironment('API_BASE', defaultValue: '');
const String _configuredApiBase = _configuredApiBaseUrl != ''
    ? _configuredApiBaseUrl
    : _legacyConfiguredApiBase != ''
        ? _legacyConfiguredApiBase
        : 'https://egg-farm-backend.onrender.com';

final String kApiBase = _normalizeApiBase(_configuredApiBase);
final String kPublicApiBase = kApiBase;

String _normalizeApiBase(String value) {
  var base = value.trim().replaceAll(RegExp(r'/+$'), '');
  base = base.replaceFirst(RegExp(r'(?:/api)+$', caseSensitive: false), '/api');
  if (!RegExp(r'/api$', caseSensitive: false).hasMatch(base)) {
    base = '$base/api';
  }
  return base;
}

String publicInvoicePdfUrl(String invoiceId) =>
    '$kPublicApiBase/public/invoices/$invoiceId/pdf';

final String kApiOrigin = Uri.parse(kApiBase).origin;
const String kCurrencySymbol = '₹';
const String kDefaultCountryCode =
    '91'; // used when a customer number has only 10 digits
const int kEggsPerCrate = 30;
