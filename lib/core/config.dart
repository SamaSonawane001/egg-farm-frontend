const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://egg-farm-backend.onrender.com/api',
);
final String kApiOrigin = Uri.parse(kApiBase).origin;
const String kCurrencySymbol = '₹';
const String kDefaultCountryCode = '91'; // used when a customer number has only 10 digits
const int kEggsPerCrate = 30;
