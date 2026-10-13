import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/facility_model.dart';

void main() {
  test('catalog amenity survives enrichment with unit type statistics', () {
    final facility = FacilityModel.fromJson({
      'id': 'facility-1',
      'name': 'Cơ sở A',
      'address': 'HCM',
      'airConditioned24h': true,
    });
    final enriched = facility.withUnitTypeStats([
      {'areaSqm': 5, 'availableUnitsCount': 2, 'basePricePerMonth': 100000},
    ]);

    expect(enriched.airConditioned24h, isTrue);
    expect(enriched.availableUnits, 2);
    expect(FacilityModel.fromJson({'id': 'unknown'}).airConditioned24h, isFalse);
  });
}
