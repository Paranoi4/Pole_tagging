import 'package:frontend/helpers/parsing.dart';
import 'role.dart';

class User {
  final int userId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix;
  final String email;
  final String? contact;
  final String username;
  final bool isActive;
  final String? authProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Role> roles;
  final String? orgCode; // ✅ ADD THIS

  User({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.suffix,
    required this.email,
    this.contact,
    required this.username,
    this.isActive = true,
    this.authProvider,
    this.createdAt,
    this.updatedAt,
    this.roles = const [],
    this.orgCode, // ✅ ADD THIS
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      middleName: json['middle_name'],
      suffix: json['suffix'],
      email: json['email'] ?? '',
      contact: json['contact'],
      username: json['username'] ?? '',
      isActive: json['is_active'] ?? true,
      authProvider: json['auth_provider'],
      createdAt: parseServerDate(json['created_at']),
      updatedAt: parseServerDate(json['updated_at']),
      roles: json['roles'] != null
          ? (json['roles'] as List).map((r) => Role.fromJson(r)).toList()
          : [],
      orgCode: json['org_code'], // ✅ ADD THIS
    );
  }

  String get fullName => '$firstName $lastName';
}
