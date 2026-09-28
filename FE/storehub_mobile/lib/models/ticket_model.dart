class TicketModel {
  final String id;
  final String ticketCode;
  final String? bookingId;
  final String? bookingCode;
  final String category;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? resolutionNote;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final String createdAt;

  TicketModel({
    required this.id,
    required this.ticketCode,
    this.bookingId,
    this.bookingCode,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.resolutionNote,
    this.assignedStaffId,
    this.assignedStaffName,
    required this.createdAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id']?.toString() ?? '',
      ticketCode: json['ticketCode'] ?? '',
      bookingId: json['bookingId']?.toString(),
      bookingCode: json['bookingCode'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'OPEN',
      priority: json['priority'] ?? 'MEDIUM',
      resolutionNote: json['resolutionNote'],
      assignedStaffId: json['assignedStaffId']?.toString(),
      assignedStaffName: json['assignedStaffName'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
