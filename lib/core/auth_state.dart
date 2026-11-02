import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthState extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  String? _token;
  Map<String, dynamic>? user;
  bool initialized = false;

  bool get isLoggedIn => _token != null && user != null;
  String get farmName => '${user?['farm_name'] ?? ''}';
  String get ownerName => '${user?['owner_name'] ?? ''}';
  String get mobile => '${user?['mobile'] ?? ''}';
  String? get avatarUrl => user?['avatar_url'] as String?;

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
          user = Map<String, dynamic>.from(await _api.get('/auth/me'));
          await prefs.setString('user', jsonEncode(user));
        } catch (error) {
          if (error is ApiException && error.status == 401) {
            _token = null;
            _api.token = null;
            user = null;
            await prefs.remove('token');
            await prefs.remove('user');
          } else if (user == null) {
            _token = null;
            _api.token = null;
            await prefs.remove('token');
          }
        }
      }
    } catch (_) {
      // Keep app startup usable if browser storage is blocked/unavailable.
      _token = null;
      user = null;
      _api.token = null;
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> _accept(dynamic res) async {
    final m = Map<String, dynamic>.from(res);
    _token = m['token'] as String;
    user = Map<String, dynamic>.from(m['user']);
    _api.token = _token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> login(String mobile, String password) async => _accept(
      await _api.post('/auth/login', {'mobile': mobile, 'password': password}));

  Future<void> register({
    required String mobile,
    required String password,
    required String ownerName,
    required String farmName,
    Uint8List? avatar,
    String? avatarName,
  }) async =>
      _accept(await _api.multipart(
        'POST',
        '/auth/register',
        {
          'mobile': mobile,
          'password': password,
          'owner_name': ownerName,
          'farm_name': farmName
        },
        fileBytes: avatar,
        fileName: avatar == null
            ? avatarName
            : _normalizeAvatarFilename(avatar, avatarName),
      ));

  Future<void> updateProfile(Map<String, String> fields,
      {Uint8List? avatar, String? avatarName}) async {
    if (avatar != null) await uploadAvatar(avatar, avatarName: avatarName);
    user = Map<String, dynamic>.from(await _api.put('/profile', fields));
    await (await SharedPreferences.getInstance())
        .setString('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> uploadAvatar(Uint8List avatar, {String? avatarName}) async {
    final res = Map<String, dynamic>.from(await _api.multipart(
      'POST',
      '/profile/upload-avatar',
      const {},
      fileBytes: avatar,
      fileName: _normalizeAvatarFilename(avatar, avatarName),
    ));
    final updatedUser = Map<String, dynamic>.from(res['user']);
    updatedUser['avatar_url'] = res['avatarUrl'];
    user = updatedUser;
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
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}
