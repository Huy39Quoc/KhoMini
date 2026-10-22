import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/user_model.dart';

void main() {
  group('UserModel Facility Affiliation Tests', () {
    test('parses facility info correctly when assigned', () {
      final json = {
        'id': 'u1',
        'username': 'staff1',
        'fullName': 'Staff 1',
        'email': 'staff1@gmail.com',
        'phone': '0374567890',
        'roleName': 'STAFF',
        'isActive': true,
        'facilityId': 'fac-1',
        'facilityName': 'Kho Mini Quận 1',
        'facilityCode': 'HCM-D1',
      };

      final user = UserModel.fromJson(json);

      expect(user.hasFacility, isTrue);
      expect(user.facilityId, 'fac-1');
      expect(user.facilityName, 'Kho Mini Quận 1');
      expect(user.facilityCode, 'HCM-D1');
      expect(user.facilityDisplayName, '[HCM-D1] Kho Mini Quận 1');
    });

    test('handles unassigned facility correctly', () {
      final json = {
        'id': 'u4',
        'username': 'staff4',
        'fullName': 'Staff 4',
        'email': 'staff4@gmail.com',
        'phone': '0374567893',
        'roleName': 'STAFF',
        'isActive': true,
        'facilityId': null,
        'facilityName': null,
        'facilityCode': null,
      };

      final user = UserModel.fromJson(json);

      expect(user.hasFacility, isFalse);
      expect(user.facilityDisplayName, 'Chưa phân cơ sở');
    });

    test('serializes to json with facility attributes', () {
      final user = UserModel(
        id: 'u2',
        username: 'staff2',
        fullName: 'Staff 2',
        email: 'staff2@gmail.com',
        phone: '0374567891',
        roleName: 'STAFF',
        isActive: true,
        facilityId: 'fac-1',
        facilityName: 'Kho Mini Quận 1',
        facilityCode: 'HCM-D1',
      );

      final map = user.toJson();

      expect(map['facilityId'], 'fac-1');
      expect(map['facilityName'], 'Kho Mini Quận 1');
      expect(map['facilityCode'], 'HCM-D1');
    });
  });
}
