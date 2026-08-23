import 'package:frontend/helpers/parsing.dart';

class Role {
  final int roleId;
  final String roleName;
  final DateTime? updatedAt;

  Role({
    required this.roleId,
    required this.roleName,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      roleId: json['role_id'],
      roleName: json['role_name'] ?? '',
      updatedAt: parseServerDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_name': roleName,
    };
  }
}