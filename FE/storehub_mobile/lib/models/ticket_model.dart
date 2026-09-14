class TicketModel {
  final String id;
  final String ticketCode;
  final int? bookingId;
  final String? bookingCode;
  final String category;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? resolutionNote;
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
    required this.createdAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id']?.toString() ?? '',
      ticketCode: json['ticketCode'] ?? '',
      bookingId: json['bookingId'],
      bookingCode: json['bookingCode'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      priority: json['priority'] ?? '',
      resolutionNote: json['resolutionNote'],
      createdAt: json['createdAt'] ?? '',
    );
  }
}
