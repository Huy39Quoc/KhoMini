class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String roleName;
  final bool isActive;
  final String? facilityId;
  final String? facilityName;
  final String? facilityCode;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleName,
    this.isActive = true,
    this.facilityId,
    this.facilityName,
    this.facilityCode,
  });

  String get role => roleName;

  bool get hasFacility =>
      facilityId != null &&
      facilityId!.isNotEmpty &&
      facilityName != null &&
      facilityName!.isNotEmpty;

  String get facilityDisplayName {
    if (!hasFacility) return 'Chưa phân cơ sở';
    if (facilityCode != null && facilityCode!.isNotEmpty) {
      return '[$facilityCode] $facilityName';
    }
    return facilityName!;
  }

  bool get hasSupportedRole => const {
        'ADMIN', 'SYSTEM_ADMIN', 'BUSINESS_MANAGER',
        'BUSINESS_OPERATIONS_MANAGER', 'OPERATIONS_MANAGER',
        'FACILITY_MANAGER', 'FACILITY_STAFF', 'STAFF', 'CUSTOMER'
      }.contains(roleName.toUpperCase().replaceAll('ROLE_', ''));

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      roleName: json['roleName']?.toString() ??
          (json['role'] is Map
              ? json['role']['name']?.toString()
              : json['role']?.toString()) ??
          'CUSTOMER',
      isActive: json['isActive'] == null || json['isActive'] == true,
      facilityId: json['facilityId']?.toString(),
      facilityName: json['facilityName']?.toString(),
      facilityCode: json['facilityCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'roleName': roleName,
        'isActive': isActive,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'facilityCode': facilityCode,
      };
}
