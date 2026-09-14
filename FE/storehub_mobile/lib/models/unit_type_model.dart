class UnitTypeModel {
  final int id;
  final String typeName;
  final String dimensions; // Dài x Rộng x Cao
  final double areaSqMeters;
  final double basePriceMonthly;
  final double depositAmount;
  final bool hasClimateControl;

  UnitTypeModel({
    required this.id,
    required this.typeName,
    required this.dimensions,
    required this.areaSqMeters,
    required this.basePriceMonthly,
    required this.depositAmount,
    required this.hasClimateControl,
  });

  factory UnitTypeModel.fromJson(Map<String, dynamic> json) {
    return UnitTypeModel(
      id: json['id'],
      typeName: json['typeName'] ?? '',
      dimensions: json['dimensions'] ?? '',
      areaSqMeters: (json['areaSqMeters'] as num).toDouble(),
      basePriceMonthly: (json['basePriceMonthly'] as num).toDouble(),
      depositAmount: (json['depositAmount'] as num).toDouble(),
      hasClimateControl: json['hasClimateControl'] ?? false,
    );
  }
}
