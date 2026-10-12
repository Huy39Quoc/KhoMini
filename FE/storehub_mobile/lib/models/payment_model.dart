import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class PaymentModel {
  final String id;
  final String transactionId;
  final String? bookingId;
  final String? bookingCode;
  final String? customerName;
  final String? customerEmail;
  final String? facilityName;
  final String? unitCode;
  final double amount;
  final String paymentType;
  final String status;
  final String? refundStatus;
  final String? paymentMethod;
  final String? note;
  final DateTime? paymentTime;

  PaymentModel({
    required this.id,
    required this.transactionId,
    this.bookingId,
    this.bookingCode,
    this.customerName,
    this.customerEmail,
    this.facilityName,
    this.unitCode,
    required this.amount,
    required this.paymentType,
    required this.status,
    this.refundStatus,
    this.paymentMethod,
    this.note,
    this.paymentTime,
  });

  String get paymentTypeLabel {
    if (transactionId.startsWith('RF-')) return 'Refund request';
    switch (paymentType.toUpperCase()) {
      case 'DEPOSIT':
        return 'Deposit Payment';
      case 'RENTAL_FEE':
        return 'Rental Fee';
      case 'EXTRA_CHARGE':
        if (note == 'RENTAL_EXTENSION') return 'Extension Fee';
        if (note == 'OVERDUE_LATE_FEE' || note == 'Phí phạt quá hạn') return 'Overdue Fee';
        return 'Extra Charge';
      default:
        return paymentType.replaceAll('_', ' ');
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Paid';
      case 'PENDING':
        return 'Pending';
      case 'REFUND_PENDING':
        return switch (refundStatus) {
          'REJECTED' => 'Refund rejected',
          'NEEDS_REVIEW' => 'Refund needs review',
          'MISSING_METADATA' => 'Refund needs payment details',
          _ => 'Refund processing',
        };
      case 'FAILED':
        return 'Failed';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PAID':
        return AppColors.success;
      case 'PENDING':
      case 'REFUND_PENDING':
        return refundStatus == 'REJECTED' ? AppColors.error : AppColors.warning;
      case 'FAILED':
        return AppColors.error;
      case 'REFUNDED':
        return AppColors.secondary;
      default:
        return AppColors.outline;
    }
  }
}
