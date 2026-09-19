class FacilityModel {
  final String id;
  final String name;
  final String address;
  final String district;
  final String city;
  final bool has24hAC;
  final double minAreaSqm;
  final double maxAreaSqm;
  final int totalUnits;
  final int availableUnits;
  final double minPricePerMonth;

  FacilityModel({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.city,
    required this.has24hAC,
    required this.minAreaSqm,
    required this.maxAreaSqm,
    required this.totalUnits,
    required this.availableUnits,
    required this.minPricePerMonth,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['facilityName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      has24hAC: json['has24hAC'] == true ||
          json['airConditioning24h'] == true ||
          json['ac24h'] == true,
      minAreaSqm: (json['minAreaSqm'] as num?)?.toDouble() ?? 0.0,
      maxAreaSqm: (json['maxAreaSqm'] as num?)?.toDouble() ?? 0.0,
      totalUnits: (json['totalUnits'] as num?)?.toInt() ?? 0,
      availableUnits: (json['availableUnits'] as num?)?.toInt() ??
          (json['availableUnitsCount'] as num?)?.toInt() ?? 0,
      minPricePerMonth: (json['minPricePerMonth'] as num?)?.toDouble() ??
          (json['basePricePerMonth'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get fullAddress =>
      [address, district, city].where((s) => s.isNotEmpty).join(', ');
}
