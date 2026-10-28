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
  final double? rentalFee;
  final double? managementFee;
  final double? depositAmount;
  final double? damageDeduction;
  final double? refundedAmount;

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
    this.rentalFee,
    this.managementFee,
    this.depositAmount,
    this.damageDeduction,
    this.refundedAmount,
  });

  String get paymentTypeLabel {
    if (transactionId.startsWith('RF-')) {
      return status.toUpperCase() == 'REFUNDED' ? 'Hoàn tiền cọc' : 'Yêu cầu hoàn tiền';
    }
    if (paymentType.toUpperCase() == 'DEPOSIT' && transactionId.startsWith('TXN-')) {
      return 'Thanh toán đơn thuê';
    }
    switch (paymentType.toUpperCase()) {
      case 'DEPOSIT':
        return 'Tiền cọc';
      case 'RENTAL_FEE':
        return 'Tiền thuê';
      case 'EXTRA_CHARGE':
        if (note == 'RENTAL_EXTENSION') return 'Phí gia hạn';
        if (note == 'OVERDUE_LATE_FEE' || note == 'Phí phạt quá hạn') return 'Phí quá hạn';
        return 'Phí phát sinh';
      default:
        return paymentType.replaceAll('_', ' ');
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Đã thanh toán';
      case 'PENDING':
        return 'Chờ thanh toán';
      case 'REFUND_PENDING':
        return switch (refundStatus) {
          'REJECTED' => 'Từ chối hoàn tiền',
          'NEEDS_REVIEW' => 'Hoàn tiền cần xem xét',
          'MISSING_METADATA' => 'Hoàn tiền thiếu thông tin',
          _ => 'Đang hoàn tiền',
        };
      case 'FAILED':
        return 'Thất bại';
      case 'REFUNDED':
        return 'Đã hoàn tiền';
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
