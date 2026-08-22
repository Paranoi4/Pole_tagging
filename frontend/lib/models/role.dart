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
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_name': roleName,
    };
  }
}
