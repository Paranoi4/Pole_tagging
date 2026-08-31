// 📁 lib/models/city.dart

class City {
  final int cityId;
  final String cityName;
  final int duId;
  final String orgCode;
  final int? createdBy;

  City({
    required this.cityId,
    required this.cityName,
    required this.duId,
    required this.orgCode,
    this.createdBy,
  });

  factory City.fromJson(Map<String, dynamic> json) => City(
        cityId: json['city_id'] as int,
        cityName: json['city_name'] as String,
        duId: json['du_id'] as int,
        orgCode: json['org_code'] as String,
        createdBy: json['created_by'] as int?,
      );
}
