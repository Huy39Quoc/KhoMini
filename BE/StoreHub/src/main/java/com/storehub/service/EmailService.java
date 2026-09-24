package com.storehub.service;

import java.math.BigDecimal;
import java.time.LocalDate;

public interface EmailService {
    void sendPasswordResetEmail(String toEmail, String fullName, String resetToken);
    void sendWelcomeEmail(String toEmail, String fullName);

    void sendBookingConfirmationEmail(
            String toEmail,
            String fullName,
            String bookingCode,
            String facilityName,
            String unitCode,
            LocalDate startDate,
            LocalDate endDate,
            BigDecimal initialPaymentAmount
    );

    void sendWaitlistNotificationEmail(
            String toEmail,
            String fullName,
            String facilityName,
            String unitTypeName
    );
}