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

  // Khớp với BE UnitTypeCatalogResponse: { id, typeName, dimensions, areaSqm,
  // basePricePerMonth, depositAmount, availableUnitsCount } - trước đây đọc
  // sai tên field (name/pricePerMonth/availableUnits) nên luôn ra giá trị 0.
  factory UnitTypeModel.fromJson(Map<String, dynamic> json) {
    return UnitTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['typeName']?.toString() ?? json['name']?.toString() ?? '',
      dimensions: json['dimensions']?.toString() ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble() ?? 0.0,
      pricePerMonth: (json['basePricePerMonth'] as num?)?.toDouble() ??
          (json['pricePerMonth'] as num?)?.toDouble() ??
          0.0,
      description: json['description']?.toString(),
      availableUnits:
          (json['availableUnitsCount'] as num?)?.toInt() ??
              (json['availableUnits'] as num?)?.toInt() ??
              0,
    );
  }
}
