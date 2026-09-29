class StaffTicketModel {
  final String id;
  final String ticketCode;
  final String bookingCode;
  final String category;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assignedStaffId;
  final String assignedStaffName;
  final String resolutionNote;
  final String createdAt;

  const StaffTicketModel({
    required this.id,
    required this.ticketCode,
    required this.bookingCode,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedStaffId,
    required this.assignedStaffName,
    required this.resolutionNote,
    required this.createdAt,
  });

  bool get isOpen => status == 'OPEN';

  bool get isInProgress => status == 'IN_PROGRESS';

  bool get isResolved => status == 'RESOLVED';
}
