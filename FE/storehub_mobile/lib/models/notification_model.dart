class NotificationModel {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final String? facilityId;
  final String? facilityName;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.referenceId,
    this.referenceType,
    this.facilityId,
    this.facilityName,
    required this.isRead,
    this.readAt,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'SYSTEM',
      referenceId: json['referenceId']?.toString(),
      referenceType: json['referenceType']?.toString(),
      facilityId: json['facilityId']?.toString(),
      facilityName: json['facilityName']?.toString(),
      isRead: json['isRead'] == true,
      readAt: parseDateTime(json['readAt']),
      createdAt: parseDateTime(json['createdAt']),
    );
  }
}
