class UnitTypeModel {
  final String id;
  final String name;
  final String dimensions;
  final double areaSqm;
  final double pricePerMonth;
  final String? description;
  final int availableUnits;

  UnitTypeModel({
    required this.id,
    required this.name,
    required this.dimensions,
    required this.areaSqm,
    required this.pricePerMonth,
    this.description,
    required this.availableUnits,
  });

  factory UnitTypeModel.fromJson(Map<String, dynamic> json) {
    return UnitTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      dimensions: json['dimensions'] ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 0.0,
      pricePerMonth: (json['pricePerMonth'] as num?)?.toDouble() ?? 0.0,
      description: json['description'],
      availableUnits: json['availableUnits'] ?? 0,
    );
  }
}
