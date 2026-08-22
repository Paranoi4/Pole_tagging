import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/models/user.dart';
import 'package:frontend/models/role.dart';
import 'package:frontend/models/auth.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ===== AUTH =====

  static Future<LoginResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          LoginRequest(username: username, password: password).toJson()),
    );

    if (response.statusCode == 200) {
      return LoginResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Login failed: ${response.statusCode}');
    }
  }

  static Future<User> getCurrentUser(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to get user: ${response.statusCode}');
    }
  }

  static Future<User> register(User user, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
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
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Registration failed: ${response.statusCode}');
    }
  }

  // ===== USERS =====

  static Future<List<User>> getUsers(String token,
      {int skip = 0, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users?skip=$skip&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  }

  static Future<User> getUserById(String token, int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load user: ${response.statusCode}');
    }
  }

  static Future<User> createUser(
      String token, User user, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create user: ${response.statusCode}');
    }
  }

  static Future<User> updateUser(
      String token, int userId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update user: ${response.statusCode}');
    }
  }

  static Future<void> deleteUser(String token, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user: ${response.statusCode}');
    }
  }

  // ===== ROLES =====

  static Future<List<Role>> getRoles(String token,
      {int skip = 0, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/roles?skip=$skip&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Role.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load roles: ${response.statusCode}');
    }
  }

  static Future<Role> createRole(String token, String roleName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/roles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'role_name': roleName}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Role.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create role: ${response.statusCode}');
    }
  }
}
