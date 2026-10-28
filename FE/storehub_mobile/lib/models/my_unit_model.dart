class MyUnitModel {
  final String bookingId;
  final String handoverIssueStatus;
  final String handoverIssueReason;
  final String handoverIssueDueAt;
  final String bookingCode;
  final String unitCode;
  final bool unitAssignmentConfirmed;
  final String facilityName;
  final String facilityAddress;
  final String typeName;
  final String status;
  final double totalRentalFee;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool hasActiveAccess;
  final String dimensions;
  final double? areaSqm;
  final int? rentalMonths;
  final double? depositPaid;
  final bool hasPendingExtension;
  final int? pendingExtraMonths;
  final DateTime? pendingNewEndDate;
  final double? pendingExtensionFee;
  final DateTime? renewalOpensDate;
  final bool overdue;
  final int overdueDays;
  final double overdueFeeOutstanding;
  final bool accessDisabled;
  final DateTime? scheduledReturnTime;
  final String? openTime;
  final String? closeTime;

  MyUnitModel({
    required this.bookingId,
    this.handoverIssueStatus = '',
    this.handoverIssueReason = '',
    this.handoverIssueDueAt = '',
    required this.bookingCode,
    required this.unitCode,
    this.unitAssignmentConfirmed = false,
    required this.facilityName,
    required this.facilityAddress,
    required this.typeName,
    required this.status,
    required this.totalRentalFee,
    this.startDate,
    this.endDate,
    this.hasActiveAccess = false,
    this.dimensions = '',
    this.areaSqm,
    this.rentalMonths,
    this.depositPaid,
    this.hasPendingExtension = false,
    this.pendingExtraMonths,
    this.pendingNewEndDate,
    this.pendingExtensionFee,
    this.renewalOpensDate,
    this.overdue = false,
    this.overdueDays = 0,
    this.overdueFeeOutstanding = 0,
    this.accessDisabled = false,
    this.scheduledReturnTime,
    this.openTime,
    this.closeTime,
  });

  bool get hasHandoverIssue =>
      handoverIssueStatus == 'OPEN' || handoverIssueStatus == 'ARRANGED';

  bool get isActive => status == 'ACTIVE';
  String get displayUnit => (isActive || unitAssignmentConfirmed)
      ? 'Ngăn $unitCode'
      : 'Đang chờ quản lý xác nhận ngăn kho';
  bool get hasLateFeeDue => overdueFeeOutstanding > 0;

  /// Chưa tới ngày được gia hạn theo chính sách của cơ sở (chỉ gia hạn trong N ngày cuối).
  bool get renewalNotYetOpen {
    final opens = renewalOpensDate;
    if (opens == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.isBefore(DateTime(opens.year, opens.month, opens.day));
  }

  double? get monthlyRate {
    if (rentalMonths == null || rentalMonths == 0) return null;
    return totalRentalFee / rentalMonths!;
  }

  String get id => bookingId;

  factory MyUnitModel.fromJson(Map<String, dynamic> json) {
    return MyUnitModel(
      bookingId: json['bookingId']?.toString() ?? json['id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      handoverIssueStatus: json['handoverIssueStatus']?.toString() ?? '',
      handoverIssueReason: json['handoverIssueReason']?.toString() ?? '',
      handoverIssueDueAt: json['handoverIssueDueAt']?.toString() ?? '',
      unitCode: json['unitCode']?.toString() ?? '',
      unitAssignmentConfirmed: json['unitAssignmentConfirmed'] == true,
      facilityName: json['facilityName']?.toString() ?? '',
      facilityAddress: json['facilityAddress']?.toString() ??
          json['address']?.toString() ??
          '',
      typeName: json['unitTypeName']?.toString() ??
          json['typeName']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      totalRentalFee: (json['totalRentalFee'] as num?)?.toDouble() ??
          (json['rentalPrice'] as num?)?.toDouble() ??
          0.0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      hasActiveAccess:
          json['activeAccess'] == true || json['hasActiveAccess'] == true,
      dimensions: json['dimensions']?.toString() ?? '',
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      rentalMonths: (json['rentalMonths'] as num?)?.toInt(),
      depositPaid: (json['depositPaid'] as num?)?.toDouble(),
      hasPendingExtension: json['hasPendingExtension'] == true,
      pendingExtraMonths: (json['pendingExtraMonths'] as num?)?.toInt(),
      pendingNewEndDate: json['pendingNewEndDate'] != null
          ? DateTime.tryParse(json['pendingNewEndDate'].toString())
          : null,
      pendingExtensionFee: (json['pendingExtensionFee'] as num?)?.toDouble(),
      renewalOpensDate: json['renewalOpensDate'] != null
          ? DateTime.tryParse(json['renewalOpensDate'].toString())
          : null,
      overdue: json['overdue'] == true,
      overdueDays: (json['overdueDays'] as num?)?.toInt() ?? 0,
      overdueFeeOutstanding:
          (json['overdueFeeOutstanding'] as num?)?.toDouble() ?? 0.0,
      accessDisabled: json['accessDisabled'] == true,
      scheduledReturnTime: json['scheduledReturnTime'] != null
          ? DateTime.tryParse(json['scheduledReturnTime'].toString())
          : null,
      openTime: json['openTime']?.toString(),
      closeTime: json['closeTime']?.toString(),
    );
  }

  String get operatingHours {
    final ot = openTime != null && openTime!.length >= 5
        ? openTime!.substring(0, 5)
        : '08:00';
    final ct = closeTime != null && closeTime!.length >= 5
        ? closeTime!.substring(0, 5)
        : '20:00';
    return '$ot - $ct';
  }

  int get openHour {
    if (openTime == null || openTime!.isEmpty) return 8;
    return int.tryParse(openTime!.split(':')[0]) ?? 8;
  }

  int get closeHour {
    if (closeTime == null || closeTime!.isEmpty) return 20;
    return int.tryParse(closeTime!.split(':')[0]) ?? 20;
  }
}
