import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import 'package:frontend/services/api_exception.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/models/auth.dart';

/// Talks to the Poletagging API.
///
/// The service holds the auth token itself, so callers never pass one in.
/// [AuthNotifier] is the only thing that sets it - on login, on restore, and
/// clearing it on logout - which keeps the token out of every screen.
///
/// Every request goes through [_send], so a timeout or a dead connection
/// surfaces as an [ApiException] with a readable message rather than a raw
/// `ClientException` landing in the UI.
class ApiService {
  static const String baseUrl = ApiConfig.baseUrl;

  /// How long to wait before giving up on a request. Without this a bad
  /// connection leaves the spinner running until the user kills the app.
  static const Duration timeout = Duration(seconds: 15);

  /// The largest page the backend allows: both list endpoints declare
  /// `limit: int = Query(10, ge=1, le=100)`, so 100 is the ceiling.
  static const int maxPageSize = 100;

  /// Stops a misbehaving server from looping forever in [_fetchAllPages].
  static const int _maxPages = 100;

  String? _token;

  /// Called by [AuthNotifier]. Pass null on logout.
  void setToken(String? token) {
    _token = (token != null && token.isEmpty) ? null : token;
  }

  /// Headers for endpoints that require a token.
  ///
  /// Throws rather than sending `Bearer null`, which the server would answer
  /// with an opaque 401.
  Map<String, String> get _authHeaders {
    final token = _token;
    if (token == null) {
      throw ApiException(401, 'Not authenticated. Please login again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, String> get _authJsonHeaders => {
        ..._authHeaders,
        'Content-Type': 'application/json',
      };

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  /// Runs one HTTP call with a timeout, turning transport failures into
  /// [ApiException] so callers only ever have one error type to handle.
  ///
  /// `dart:io` is deliberately not imported - this app builds for web, where
  /// `SocketException` does not exist - so the connection case is caught
  /// broadly instead of by type.
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on ApiException {
      // Thrown by _authHeaders while building the request; already readable.
      rethrow;
    } on TimeoutException {
      throw ApiException(
        0,
        'The server took too long to respond. Please try again.',
      );
    } catch (_) {
      throw ApiException(
        0,
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  /// Walks every page of a paginated endpoint and returns the lot.
  ///
  /// The list endpoints default to 10 items, so a single call quietly returned
  /// only the first 10 users or roles with nothing to say the rest existed.
  Future<List<T>> _fetchAllPages<T>(
    Future<List<T>> Function(int skip, int limit) fetchPage,
  ) async {
    final all = <T>[];
    var skip = 0;

    for (var page = 0; page < _maxPages; page++) {
      final items = await fetchPage(skip, maxPageSize);
      all.addAll(items);

      // A short page means that was the last one.
      if (items.length < maxPageSize) break;
      skip += maxPageSize;
    }

    return all;
  }

  // ===== AUTH =====

  Future<LoginResponse> login(String username, String password) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: _jsonHeaders,
          body: jsonEncode(
              LoginRequest(username: username, password: password).toJson()),
        ));

    if (response.statusCode == 200) {
      return LoginResponse.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Login failed: ${response.statusCode}',
      );
    }
  }

  Future<User> getCurrentUser() async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/me'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      // The backend's own 401 wording here is about the token, which says
      // nothing useful to someone staring at the screen.
      throw ApiException(401, 'Session expired. Please login again.');
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to get user: ${response.statusCode}',
      );
    }
  }

  Future<User> register(User user, String password) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'first_name': user.firstName,
            'last_name': user.lastName,
            'middle_name': user.middleName,
            'suffix': user.suffix,
            'email': user.email,
            'contact': user.contact,
            'username': user.username,
            'password': password,
          }),
        ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Registration failed: ${response.statusCode}',
      );
    }
  }

  // ===== USERS =====

  /// Every user, walking the pages. Use this for list screens.
  Future<List<User>> getAllUsers() =>
      _fetchAllPages((skip, limit) => getUsers(skip: skip, limit: limit));

  /// One page of users. Prefer [getAllUsers] unless you are paging yourself.
  Future<List<User>> getUsers({int skip = 0, int limit = maxPageSize}) async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/users?skip=$skip&limit=$limit'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load users: ${response.statusCode}',
      );
    }
  }

  Future<User> getUserById(int userId) async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/users/$userId'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load user: ${response.statusCode}',
      );
    }
  }

  Future<User> createUser(User user, String password) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/users'),
          headers: _authJsonHeaders,
          body: jsonEncode({
            'first_name': user.firstName,
            'last_name': user.lastName,
            'middle_name': user.middleName,
            'suffix': user.suffix,
            'email': user.email,
            'contact': user.contact,
            'username': user.username,
            'password': password,
          }),
        ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to create user: ${response.statusCode}',
      );
    }
  }

  Future<User> updateUser(int userId, Map<String, dynamic> data) async {
    final response = await _send(() => http.put(
          Uri.parse('$baseUrl/users/$userId'),
          headers: _authJsonHeaders,
          body: jsonEncode(data),
        ));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to update user: ${response.statusCode}',
      );
    }
  }

  Future<void> deleteUser(int userId) async {
    final response = await _send(() => http.delete(
          Uri.parse('$baseUrl/users/$userId'),
          headers: _authHeaders,
        ));

    if (response.statusCode != 200) {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to delete user: ${response.statusCode}',
      );
    }
  }

  // ===== ROLES =====

  /// Every role, walking the pages. Use this for list screens.
  Future<List<Role>> getAllRoles() =>
      _fetchAllPages((skip, limit) => getRoles(skip: skip, limit: limit));

  /// One page of roles. Prefer [getAllRoles] unless you are paging yourself.
  Future<List<Role>> getRoles({int skip = 0, int limit = maxPageSize}) async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/roles?skip=$skip&limit=$limit'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Role.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load roles: ${response.statusCode}',
      );
    }
  }

  Future<Role> createRole(String roleName) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/roles'),
          headers: _authJsonHeaders,
          body: jsonEncode({'role_name': roleName}),
        ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Role.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to create role: ${response.statusCode}',
      );
    }
  }

  // ===== USER ROLES =====
  // Both endpoints are Admin-only on the backend (require_role("Admin")).
  // A non-Admin calling these gets a 403, surfaced as an ApiException.

  Future<void> assignRoleToUser(int userId, int roleId) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/user-roles'),
          headers: _authJsonHeaders,
          body: jsonEncode({'user_id': userId, 'role_id': roleId}),
        ));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to assign role: ${response.statusCode}',
      );
    }
  }

  Future<void> removeRoleFromUser(int userId, int roleId) async {
    final response = await _send(() => http.delete(
          Uri.parse('$baseUrl/user-roles/user/$userId/role/$roleId'),
          headers: _authHeaders,
        ));

    if (response.statusCode != 200) {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to remove role: ${response.statusCode}',
      );
    }
  }
}
