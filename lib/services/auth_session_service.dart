import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.role,
  });

  final String accessToken;
  final String userId;
  final String role;
}

class AuthSessionService {
  static const _tokenKey = 'auth_access_token';
  static const _userIdKey = 'auth_user_id';
  static const _roleKey = 'auth_role';

  static Future<void> save({
    required String accessToken,
    required String userId,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_roleKey, role);
  }

  static Future<AuthSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final role = prefs.getString(_roleKey);
    if (token == null || token.isEmpty || userId == null || role == null) {
      return null;
    }
    return AuthSession(accessToken: token, userId: userId, role: role);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_roleKey);
  }
}

class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final session = await AuthSessionService.load();
    if (session != null && !request.headers.containsKey('Authorization')) {
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
