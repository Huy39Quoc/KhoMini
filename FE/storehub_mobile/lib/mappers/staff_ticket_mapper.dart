import '../models/staff_ticket_model.dart';

class StaffTicketMapper {
  const StaffTicketMapper._();

  static StaffTicketModel fromJson(
      Map<String, dynamic> json,
      ) {
    return StaffTicketModel(
      id: _text(json['id']),
      ticketCode: _text(json['ticketCode']),
      bookingCode: _text(json['bookingCode']),
      category: _text(json['category']),
      title: _text(json['title']),
      description: _text(json['description']),
      status: _text(json['status']),
      priority: _text(json['priority']),
      assignedStaffId: _text(json['assignedStaffId']),
      assignedStaffName: _text(json['assignedStaffName']),
      resolutionNote: _text(json['resolutionNote']),
      createdAt: _text(json['createdAt']),
    );
  }

  static Map<String, dynamic> statusRequestToJson({
    required String status,
    String? resolutionNote,
  }) {
    return {
      'status': status,
      if (resolutionNote != null &&
          resolutionNote.trim().isNotEmpty)
        'resolutionNote': resolutionNote.trim(),
    };
  }

  static Map<String, dynamic> asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static String _text(dynamic value) {
    return value?.toString() ?? '';
  }
}