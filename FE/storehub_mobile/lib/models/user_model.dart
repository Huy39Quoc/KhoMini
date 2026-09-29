class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String roleName;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleName,
  });

  // Getter cho các màn hình dùng u.role
  String get role => roleName;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'roleName': roleName,
      };
}
