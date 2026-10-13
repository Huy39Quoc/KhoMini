class FacilityModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String contactPhone;
  final String status;
  final bool airConditioned24h;

  final double? minAreaSqm;
  final double? maxAreaSqm;
  final double? minPricePerMonth;
  final int? availableUnits;
  final int? unitTypeCount;

  FacilityModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.contactPhone = '',
    this.status = 'ACTIVE',
    this.airConditioned24h = false,
    this.minAreaSqm,
    this.maxAreaSqm,
    this.minPricePerMonth,
    this.availableUnits,
    this.unitTypeCount,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      airConditioned24h: json['airConditioned24h'] == true,
    );
  }

  bool get isBookable => status == 'ACTIVE';

  String get fullAddress =>
      [address, city].where((s) => s.isNotEmpty).join(', ');

  FacilityModel withUnitTypeStats(List<dynamic> unitTypes) {
    if (unitTypes.isEmpty) {
      return FacilityModel(
        id: id,
        name: name,
        address: address,
        city: city,
        contactPhone: contactPhone,
        status: status,
        airConditioned24h: airConditioned24h,
        unitTypeCount: 0,
        availableUnits: 0,
      );
    }

    double? minArea, maxArea, minPrice;
    int totalAvailable = 0;

    for (final raw in unitTypes) {
      if (raw is! Map) continue;
      final area = (raw['areaSqm'] as num?)?.toDouble();
      final price = (raw['basePricePerMonth'] as num?)?.toDouble();
      final available = (raw['availableUnitsCount'] as num?)?.toInt() ?? 0;

      if (area != null) {
        minArea = (minArea == null) ? area : (area < minArea ? area : minArea);
        maxArea = (maxArea == null) ? area : (area > maxArea ? area : maxArea);
      }
      if (price != null) {
        minPrice =
            (minPrice == null) ? price : (price < minPrice ? price : minPrice);
      }
      totalAvailable += available;
    }

    return FacilityModel(
      id: id,
      name: name,
      address: address,
      city: city,
      contactPhone: contactPhone,
      status: status,
      airConditioned24h: airConditioned24h,
      minAreaSqm: minArea,
      maxAreaSqm: maxArea,
      minPricePerMonth: minPrice,
      availableUnits: totalAvailable,
      unitTypeCount: unitTypes.length,
    );
  }
}
