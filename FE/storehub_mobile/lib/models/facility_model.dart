/// Matches BE FacilityResponse: { id, name, code, address, city,
/// contactPhone, email, managerId, managerName, status, openTime,
/// closeTime, description, createdAt, updatedAt }. Area/price/availability
/// still aren't facility fields - those come from aggregating GET
/// /catalog/unit-types?facilityId=... (see withUnitTypeStats), and stay
/// null ("not loaded yet") rather than silently defaulting to 0.
class FacilityModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String contactPhone;
  final String status; // ACTIVE, INACTIVE, MAINTENANCE

  // Derived from unit types (nullable = not computed / no unit types yet)
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
    );
  }

  bool get isBookable => status == 'ACTIVE';

  String get fullAddress =>
      [address, city].where((s) => s.isNotEmpty).join(', ');

  /// Returns a copy of this facility with real stats computed from its
  /// unit types (as returned by GET /catalog/unit-types?facilityId=...:
  /// areaSqm, basePricePerMonth, availableUnitsCount per type).
  FacilityModel withUnitTypeStats(List<dynamic> unitTypes) {
    if (unitTypes.isEmpty) {
      return FacilityModel(
        id: id,
        name: name,
        address: address,
        city: city,
        contactPhone: contactPhone,
        status: status,
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
      // Note: this field has been observed coming back as a UUID string
      // instead of a count on some BE builds (likely an upstream bug) - the
      // `as num?` cast safely yields null / 0 rather than crashing.
      final available = (raw['availableUnitsCount'] as num?)?.toInt() ?? 0;

      if (area != null) {
        minArea = (minArea == null) ? area : (area < minArea ? area : minArea);
        maxArea = (maxArea == null) ? area : (area > maxArea ? area : maxArea);
      }
      if (price != null) {
        minPrice = (minPrice == null) ? price : (price < minPrice ? price : minPrice);
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
      minAreaSqm: minArea,
      maxAreaSqm: maxArea,
      minPricePerMonth: minPrice,
      availableUnits: totalAvailable,
      unitTypeCount: unitTypes.length,
    );
  }
}
