import '../models/payment_model.dart';

class PaymentMapper {
  const PaymentMapper._();

  static PaymentModel fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString() ?? '',
      transactionId: json['transactionId']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      bookingCode: json['bookingCode']?.toString(),
      customerName: json['customerName']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
      facilityName: json['facilityName']?.toString(),
      unitCode: json['unitCode']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentType: json['paymentType']?.toString() ?? 'DEPOSIT',
      status: json['status']?.toString() ?? 'PENDING',
      refundStatus: json['refundStatus']?.toString(),
      paymentMethod: json['paymentMethod']?.toString(),
      note: json['note']?.toString(),
      paymentTime: DateTime.tryParse(json['paymentTime']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Invalid payment data');
  }
}
