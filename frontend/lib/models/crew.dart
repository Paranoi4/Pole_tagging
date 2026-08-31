// 📁 lib/models/crew.dart

import 'package:frontend/models/city.dart';

class Crew {
  final int crewId;
  final String crewLabel;
  final int? cityId;
  final City? city;
  final String orgCode;
  final int? createdBy;

  Crew({
    required this.crewId,
    required this.crewLabel,
    this.cityId,
    this.city,
    required this.orgCode,
    this.createdBy,
  });

  factory Crew.fromJson(Map<String, dynamic> json) => Crew(
        crewId: json['crew_id'] as int,
        crewLabel: json['crew_label'] as String,
        cityId: json['city_id'] as int?,
        city: json['city'] != null
            ? City.fromJson(json['city'] as Map<String, dynamic>)
            : null,
        orgCode: json['org_code'] as String,
        createdBy: json['created_by'] as int?,
      );
}
