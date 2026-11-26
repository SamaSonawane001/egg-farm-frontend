import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthState extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  final ValueNotifier<int> _routeRefreshVersion = ValueNotifier<int>(0);
  String? _token;
  Map<String, dynamic>? user;
  List<Map<String, dynamic>> farms = [];
  String? _selectedFarmId;
  bool initialized = false;

  bool get isLoggedIn => _token != null && user != null;
  bool get sharedInventoryEnabled => user?['shared_inventory_enabled'] == true;
  Listenable get routeRefreshListenable => _routeRefreshVersion;
  bool get isAllFarms => _selectedFarmId == 'all';
  String? get selectedFarmId => _selectedFarmId;
  Map<String, dynamic>? get primaryFarm {
    for (final farm in farms) {
      if (farm['is_primary'] == true) return farm;
    }
    return farms.isEmpty ? null : farms.first;
  }

  String get farmName =>
      '${primaryFarm?['farm_name'] ?? user?['farm_name'] ?? ''}';
  String get selectedFarmName {
    if (isAllFarms) return 'All Farms Combined · एकत्रित हिशोब';
    for (final farm in farms) {
      if (farm['farm_id'] == _selectedFarmId) {
        return '${farm['farm_name'] ?? user?['farm_name'] ?? ''}';
      }
    }
    return '${user?['farm_name'] ?? ''}';
  }

  bool get isSecondaryFarm =>
      _selectedFarmId != null &&
      _selectedFarmId != 'all' &&
      _selectedFarmId != primaryFarm?['farm_id'];

  String get ownerName => '${user?['owner_name'] ?? ''}';
  String get mobile => '${user?['mobile'] ?? ''}';
  String? get avatarUrl =>
      primaryFarm?['avatar_url'] as String? ?? user?['avatar_url'] as String?;
  String? get signatureUrl =>
      primaryFarm?['signature_url'] as String? ??
      user?['signature_url'] as String?;
  String? get paymentQrUrl =>
      primaryFarm?['payment_qr_url'] as String? ??
      user?['payment_qr_url'] as String?;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _api.onUnauthorized = () => logout();
      _token = prefs.getString('token');
      _api.token = _token;
      if (_token != null) {
        final cachedUser = prefs.getString('user');
        if (cachedUser != null) {
          try {
            user = Map<String, dynamic>.from(jsonDecode(cachedUser) as Map);
          } catch (_) {
            await prefs.remove('user');
          }
        }
        try {
          farms = List<Map<String, dynamic>>.from(
            (await _api.get('/farms') as List).map(
              (farm) => Map<String, dynamic>.from(farm as Map),
            ),
          );
          final savedFarmId = prefs.getString('farmId');
          final validSelection =
              farms.any((farm) => farm['farm_id'] == savedFarmId);
          _selectedFarmId = savedFarmId == 'all'
              ? 'all'
              : validSelection
                  ? savedFarmId
                  : farms.isEmpty
                      ? null
                      : '${farms.first['farm_id']}';
          _api.farmId = _selectedFarmId;
          user = Map<String, dynamic>.from(await _api.get('/auth/me'));
          await prefs.setString('user', jsonEncode(user));
          if (_selectedFarmId != null) {
            await prefs.setString('farmId', _selectedFarmId!);
          }
        } catch (error) {
          if (error is ApiException &&
              (error.code == 'AUTH_INVALID' || error.code == 'AUTH_REQUIRED')) {
            _token = null;
            _api.token = null;
            _api.farmId = null;
            user = null;
            await prefs.remove('token');
            await prefs.remove('user');
            await prefs.remove('farmId');
          }
        }
      }
    } catch (_) {
      // Keep app startup usable if browser storage is blocked/unavailable.
      _token = null;
      user = null;
      _api.token = null;
      _api.farmId = null;
    } finally {
      initialized = true;
      _routeRefreshVersion.value++;
      notifyListeners();
    }
  }

  Future<void> _accept(dynamic res) async {
    final m = Map<String, dynamic>.from(res);
    _token = m['token'] as String;
    user = Map<String, dynamic>.from(m['user']);
    _api.token = _token;
    _selectedFarmId = '${user?['farm_id'] ?? ''}';
    _api.farmId = _selectedFarmId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('user', jsonEncode(user));
    if (_selectedFarmId!.isNotEmpty) {
      await prefs.setString('farmId', _selectedFarmId!);
    }
    farms = List<Map<String, dynamic>>.from(
      (await _api.get('/farms') as List).map(
        (farm) => Map<String, dynamic>.from(farm as Map),
      ),
    );
    _routeRefreshVersion.value++;
    notifyListeners();
  }

  Future<void> login(String mobile, String password) async {
    _api.farmId = null;
    await _accept(await _api.post('/auth/login', {
      'mobile': mobile,
      'password': password,
    }));
  }

  Future<void> sendSignupOtp(String phone) async {
    _api.farmId = null;
    await _api.post('/auth/send-signup-otp', {'phone': phone});
  }

  Future<void> sendResetOtp(String phone) async {
    _api.farmId = null;
    await _api.post('/auth/send-reset-otp', {'phone': phone});
  }

  Future<void> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    _api.farmId = null;
    await _api.post('/auth/reset-password', {
      'phone': phone,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  Future<String> verifySignupOtp(String phone, String otp) async {
    _api.farmId = null;
    final response = Map<String, dynamic>.from(
      await _api.post('/auth/verify-signup-otp', {
        'phone': phone,
        'otp': otp,
      }),
    );
    return response['phone_verification_token'] as String;
  }

  Future<void> register({
    required String mobile,
    required String password,
    required String ownerName,
    required String farmName,
    required String phoneVerificationToken,
    required bool consentAccepted,
    required String consentVersion,
    Uint8List? avatar,
    String? avatarName,
  }) async {
    _api.farmId = null;
    await _accept(await _api.multipart(
      'POST',
      '/auth/register',
      {
        'mobile': mobile,
        'password': password,
        'owner_name': ownerName,
        'farm_name': farmName,
        'phone_verification_token': phoneVerificationToken,
        'consent_accepted': consentAccepted.toString(),
        'consent_version': consentVersion,
      },
      fileBytes: avatar,
      fileName: avatar == null
          ? avatarName
          : _normalizeAvatarFilename(avatar, avatarName),
    ));
  }

  Future<void> selectFarm(String farmId) async {
    final previous = _selectedFarmId;
    _selectedFarmId = farmId;
    _api.farmId = farmId == 'all' ? 'all' : farmId;
    notifyListeners();
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.setString('farmId', farmId);
      if (farmId != 'all') {
        final selectedUser =
            Map<String, dynamic>.from(await _api.get('/auth/me'));
        await prefs.setString('user', jsonEncode(selectedUser));
        user = selectedUser;
        notifyListeners();
      }
    } catch (_) {
      _selectedFarmId = previous;
      _api.farmId = previous;
      if (prefs != null) {
        if (previous == null) {
          await prefs.remove('farmId');
        } else {
          await prefs.setString('farmId', previous);
        }
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createFarm(String name, {required bool copyBranding}) async {
    final created = Map<String, dynamic>.from(await _api.post('/farms', {
      'name': name,
      'copy_branding': copyBranding,
    }));
    await _refreshFarms();
    await selectFarm('${created['farm_id']}');
  }

  Future<void> renameFarm(String farmId, String name) async {
    await _api.put('/farms/$farmId', {'name': name});
    await _refreshFarms();
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields,
      {Uint8List? avatar, String? avatarName}) async {
    if (avatar != null) await uploadAvatar(avatar, avatarName: avatarName);
    await _api.put('/farm/profile', fields);
    await _refreshProfile();
  }

  Future<void> setSharedInventoryEnabled(bool enabled) async {
    await _api.patch('/profile/inventory-mode', {
      'shared_inventory_enabled': enabled,
    });
    await _refreshProfile();
  }

  Future<void> uploadAvatar(Uint8List avatar, {String? avatarName}) async {
    await _api.multipart(
      'POST',
      '/profile/upload-avatar',
      const {},
      fileBytes: avatar,
      fileName: _normalizeAvatarFilename(avatar, avatarName),
    );
    await _refreshProfile();
  }

  Future<void> uploadFarmAsset(
      String asset, Uint8List image, String imageName) async {
    final path = asset == 'signature' ? '/farm/signature' : '/farm/payment-qr';
    await _api.multipart(
      'POST',
      path,
      const {},
      fileBytes: image,
      fileName: imageName,
      fileField: 'image',
    );
    await _refreshProfile();
  }

  Future<void> removeFarmAsset(String asset) async {
    final path = asset == 'signature' ? '/farm/signature' : '/farm/payment-qr';
    await _api.delete(path);
    await _refreshProfile();
  }

  Future<void> _refreshFarms() async {
    farms = List<Map<String, dynamic>>.from(
      (await _api.get('/farms') as List).map(
        (farm) => Map<String, dynamic>.from(farm as Map),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    await _refreshFarms();
    user = Map<String, dynamic>.from(await _api.get('/auth/me'));
    await (await SharedPreferences.getInstance())
        .setString('user', jsonEncode(user));
    notifyListeners();
  }

  String _normalizeAvatarFilename(Uint8List bytes, String? filename) {
    final name = (filename ?? 'avatar').split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff
        ? '.jpg'
        : bytes.length >= 8 &&
                bytes[0] == 0x89 &&
                bytes[1] == 0x50 &&
                bytes[2] == 0x4e &&
                bytes[3] == 0x47 &&
                bytes[4] == 0x0d &&
                bytes[5] == 0x0a &&
                bytes[6] == 0x1a &&
                bytes[7] == 0x0a
            ? '.png'
            : bytes.length >= 12 &&
                    String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
                    String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP'
                ? '.webp'
                : dot > 0
                    ? name.substring(dot).toLowerCase()
                    : '.jpg';
    return '$stem$extension';
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    farms = [];
    _selectedFarmId = null;
    _api.token = null;
    _api.farmId = null;
    _routeRefreshVersion.value++;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('farmId');
  }

  @override
  void dispose() {
    _routeRefreshVersion.dispose();
    super.dispose();
  }
}
