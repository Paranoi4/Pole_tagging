import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/config/api_config.dart';
import 'package:frontend/services/api_exception.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/models/auth.dart';
import 'package:frontend/models/du.dart';
import 'package:frontend/models/batch.dart';
import 'package:frontend/models/work_order.dart';
import 'package:frontend/models/tag.dart';
import 'package:frontend/models/city.dart';
import 'package:frontend/models/crew.dart';

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

  /// Most tag ids `PATCH /tags/bulk/status` accepts in one call - the handler
  /// rejects anything above 100 with a 400.
  static const int maxBulkTagIds = 100;

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
            'org_code': user.orgCode,
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

  Future<List<DU>> getDUs() async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/du'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => DU.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load DUs: ${response.statusCode}',
      );
    }
  }

  /// The code the next batch will be given, e.g. `BT-N-2026-0042`.
  ///
  /// The server derives it with the same generator that stamps the real batch,
  /// so the create form shows the code it will actually get. Takes no DU: an
  /// org owns one, and the token already says which org.
  Future<String> getNextBatchCode() async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/batches/next-code'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['next_batch_code'] as String;
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load next batch code: ${response.statusCode}',
      );
    }
  }

  Future<List<Batch>> getAllBatches() => _fetchAllPages(
      (skip, limit) => _getBatchesPage(skip: skip, limit: limit));

  Future<List<Batch>> _getBatchesPage(
      {int skip = 0, int limit = maxPageSize}) async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/batches?skip=$skip&limit=$limit'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Batch.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load batches: ${response.statusCode}',
      );
    }
  }

  /// Searches the caller's work orders by code or name, for the batch form's
  /// type-ahead. Pass an empty [search] for the 20 most recent.
  ///
  /// The backend caps this at 20 and scopes it to the caller's org, so it is
  /// safe to call per keystroke (debounce on the UI side).
  Future<List<WorkOrder>> searchWorkOrders({String search = ''}) async {
    final trimmed = search.trim();
    final url = trimmed.isEmpty
        ? '$baseUrl/work-orders'
        : '$baseUrl/work-orders?search=${Uri.encodeQueryComponent(trimmed)}';

    final response = await _send(() => http.get(
          Uri.parse(url),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => WorkOrder.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load work orders: ${response.statusCode}',
      );
    }
  }

  Future<Batch> createBatch({
    required int duId,
    required int workOrderId,
    required int quantity,
    int? assignedTo,
  }) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/batches'),
          headers: _authJsonHeaders,
          body: jsonEncode({
            'du_id': duId,
            'work_order_id': workOrderId,
            'quantity': quantity,
            'assigned_to': assignedTo,
          }),
        ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Batch.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to create batch: ${response.statusCode}',
      );
    }
  }

  /// Get tags for a specific batch
  Future<List<Tag>> getBatchTags(int batchId) async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/batches/$batchId/tags'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Tag.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load batch tags: ${response.statusCode}',
      );
    }
  }

  /// The caller's own batch that is still waiting to be printed, or null.
  ///
  /// Scoped to the signed-in user, not the org: two printermen on the same
  /// shift each get the batch they created. Returns null when nothing is
  /// awaiting print — a normal state, so the screen shows its empty message.
  Future<Batch?> getMyCurrentBatch() async {
    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/batches/my-current'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      return Batch.fromJson(data as Map<String, dynamic>);
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load current batch: ${response.statusCode}',
      );
    }
  }

  /// Update batch status
  Future<Batch> updateBatchStatus(int batchId, String status) async {
    final response = await _send(() => http.patch(
          Uri.parse('$baseUrl/batches/$batchId/status?status=$status'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      return Batch.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to update batch status: ${response.statusCode}',
      );
    }
  }

  /// Update a single tag's status
  Future<Tag> updateTagStatus(int tagId, String status) async {
    final response = await _send(() => http.patch(
          Uri.parse('$baseUrl/tags/$tagId/status?status=$status'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      return Tag.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to update tag status: ${response.statusCode}',
      );
    }
  }

  /// Sets the same status on many tags, in chunks the backend will accept.
  ///
  /// `PATCH /tags/bulk/status` refuses more than [maxBulkTagIds] ids per call,
  /// so a 500-tag batch goes out as 5 requests rather than one. The print sheet
  /// used to update tags one at a time, which meant one request per tag.
  ///
  /// Not atomic across chunks: if the third request fails, the first two are
  /// already committed. Callers should re-read the batch on failure rather than
  /// assume nothing changed.
  Future<void> bulkUpdateTagStatus(List<int> tagIds, String status) async {
    if (tagIds.isEmpty) return;

    for (var start = 0; start < tagIds.length; start += maxBulkTagIds) {
      final end = (start + maxBulkTagIds).clamp(0, tagIds.length);
      final chunk = tagIds.sublist(start, end);

      // The endpoint takes tag_ids as a repeated query param, not a JSON body.
      final query = chunk.map((id) => 'tag_ids=$id').join('&');
      final response = await _send(() => http.patch(
            Uri.parse('$baseUrl/tags/bulk/status?$query&status=$status'),
            headers: _authHeaders,
          ));

      if (response.statusCode != 200) {
        throw ApiException.fromResponse(
          response.statusCode,
          response.body,
          fallback: 'Failed to update tag statuses: ${response.statusCode}',
        );
      }
    }
  }

  // ===== CITIES =====

  /// Searches cities within a DU by name, for the crew form's City/Area
  /// autocomplete. Pass an empty [search] to list all cities for the DU.
  ///
  /// The backend caps this at 20 results and scopes it to the DU and the
  /// caller's org, so this is safe to call on every keystroke (debounce on
  /// the UI side to avoid firing one request per character).
  Future<List<City>> searchCities(
      {required int duId, String search = ''}) async {
    final trimmed = search.trim();
    final url = trimmed.isEmpty
        ? '$baseUrl/cities?du_id=$duId'
        : '$baseUrl/cities?du_id=$duId&search=${Uri.encodeQueryComponent(trimmed)}';

    final response = await _send(() => http.get(
          Uri.parse(url),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => City.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to search cities: ${response.statusCode}',
      );
    }
  }

  // ===== CREWS =====

  /// Creates a crew. [cityId] must be the id of an existing city (from
  /// [searchCities]) — the form does not let admins type a city that
  /// doesn't already exist.
  Future<Crew> createCrew({required String crewLabel, int? cityId}) async {
    final response = await _send(() => http.post(
          Uri.parse('$baseUrl/crews'),
          headers: _authJsonHeaders,
          body: jsonEncode({
            'crew_label': crewLabel,
            'city_id': cityId,
          }),
        ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Crew.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to create crew: ${response.statusCode}',
      );
    }
  }

  Future<List<Crew>> getAllCrews({int? cityId}) => _fetchAllPages(
      (skip, limit) => _getCrewsPage(skip: skip, limit: limit, cityId: cityId));

  Future<List<Crew>> _getCrewsPage({
    int skip = 0,
    int limit = maxPageSize,
    int? cityId,
  }) async {
    final params = <String>['skip=$skip', 'limit=$limit'];
    if (cityId != null) params.add('city_id=$cityId');

    final response = await _send(() => http.get(
          Uri.parse('$baseUrl/crews?${params.join('&')}'),
          headers: _authHeaders,
        ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Crew.fromJson(json)).toList();
    } else {
      throw ApiException.fromResponse(
        response.statusCode,
        response.body,
        fallback: 'Failed to load crews: ${response.statusCode}',
      );
    }
  }
}
