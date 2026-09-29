package com.storehub.service.impl;

import com.storehub.service.EmailService;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailServiceImpl implements EmailService {

    private static final DecimalFormat CURRENCY_FMT = new DecimalFormat("#,###");
    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String fromEmail;

    @Value("${app.frontend-url}")
    private String frontendUrl;


    @Override
    public void sendPasswordResetEmail(String toEmail, String fullName, String resetToken) {
        String resetLink = frontendUrl + "/reset-password?token=" + resetToken;
        String subject = "Reset Your Password";
        String content = """
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <h2>Password Reset Request</h2>
                    <p>Hi <strong>%s</strong>,</p>
                    <p>We received a request to reset your password.</p>
                    <p>This link will expire in <strong>15 minutes</strong>.</p>
                    <a href="%s"
                       style="display: inline-block; padding: 12px 24px; margin: 16px 0;
                              background-color: #4F46E5; color: white;
                              text-decoration: none; border-radius: 6px;">
                        Reset Password
                    </a>
                    <p>If you did not request this, please ignore this email.</p>
                    <hr/>
                    <p style="color: #999; font-size: 12px;">Store Hub Platform</p>
                </div>
                """.formatted(fullName, resetLink);

        sendHtmlEmail(toEmail, subject, content);
    }


    @Override
    public void sendWelcomeEmail(String toEmail, String fullName) {
        String loginLink = frontendUrl + "/login";
        String subject = "Welcome to Store Hub!";
        String content = """
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <h2>Welcome to Store Hub!</h2>
                    <p>Hi <strong>%s</strong>,</p>
                    <p>Your account has been created successfully.</p>
                    <a href="%s"
                       style="display: inline-block; padding: 12px 24px; margin: 16px 0;
                              background-color: #4F46E5; color: white;
                              text-decoration: none; border-radius: 6px;">
                        Go to StoreHub platform
                    </a>
                    <hr/>
                    <p style="color: #999; font-size: 12px;">Store Hub Platform</p>
                </div>
                """.formatted(fullName, loginLink);

        sendHtmlEmail(toEmail, subject, content);
    }

    @Override
    @Async
    public void sendBookingConfirmationEmail(
            String toEmail,
            String fullName,
            String bookingCode,
            String facilityName,
            String unitCode,
            LocalDate startDate,
            LocalDate endDate,
            BigDecimal initialPaymentAmount
    ) {
        String subject = "✅ Đặt chỗ thành công – Mã đơn: " + bookingCode;
        String amountStr = initialPaymentAmount != null
                ? CURRENCY_FMT.format(initialPaymentAmount) + " ₫"
                : "–";
        String content = """
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
                  <div style="background: linear-gradient(135deg, #1E3C72, #2A5298); padding: 28px 24px; text-align: center;">
                    <h1 style="color: white; margin: 0; font-size: 22px;">🎉 Đặt chỗ thành công!</h1>
                    <p style="color: rgba(255,255,255,0.8); margin: 8px 0 0;">Store Hub – Kho lưu trữ thông minh</p>
                  </div>
                  <div style="padding: 28px 24px; background: #fff;">
                    <p>Xin chào <strong>%s</strong>,</p>
                    <p>Đơn đặt chỗ kho của bạn đã được xác nhận thành công. Dưới đây là thông tin chi tiết:</p>
                    <table style="width:100%%; border-collapse:collapse; margin-top:16px;">
                      <tr style="background:#f9fafb;">
                        <td style="padding:10px 14px; font-weight:bold; width:40%%;">Mã đơn đặt chỗ</td>
                        <td style="padding:10px 14px; font-family:monospace; font-size:18px; letter-spacing:2px; color:#1E3C72;"><strong>%s</strong></td>
                      </tr>
                      <tr>
                        <td style="padding:10px 14px; font-weight:bold;">Cơ sở</td>
                        <td style="padding:10px 14px;">%s</td>
                      </tr>
                      <tr style="background:#f9fafb;">
                        <td style="padding:10px 14px; font-weight:bold;">Mã kho được cấp</td>
                        <td style="padding:10px 14px;">%s</td>
                      </tr>
                      <tr>
                        <td style="padding:10px 14px; font-weight:bold;">Ngày bắt đầu</td>
                        <td style="padding:10px 14px;">%s</td>
                      </tr>
                      <tr style="background:#f9fafb;">
                        <td style="padding:10px 14px; font-weight:bold;">Ngày kết thúc</td>
                        <td style="padding:10px 14px;">%s</td>
                      </tr>
                      <tr>
                        <td style="padding:10px 14px; font-weight:bold;">Tổng thanh toán</td>
                        <td style="padding:10px 14px; color:#1E3C72; font-size:17px;"><strong>%s</strong></td>
                      </tr>
                    </table>
                    <div style="background:#f0f4ff; border-radius:8px; padding:16px; margin-top:20px;">
                      <p style="margin:0; font-size:13px; color:#374151;">
                        📌 Vui lòng mang theo <strong>mã đơn đặt chỗ</strong> và CMND/CCCD khi đến nhận kho.<br/>
                        Nếu cần hỗ trợ, liên hệ chúng tôi qua app hoặc email này.
                      </p>
                    </div>
                  </div>
                  <div style="background:#f9fafb; padding:16px 24px; text-align:center;">
                    <p style="color:#9ca3af; font-size:12px; margin:0;">Store Hub Platform – storehub.vn</p>
                  </div>
                </div>
                """.formatted(
                fullName, bookingCode, facilityName, unitCode,
                startDate != null ? startDate.format(DATE_FMT) : "–",
                endDate != null ? endDate.format(DATE_FMT) : "–",
                amountStr
        );

        sendHtmlEmail(toEmail, subject, content);
    }

    @Override
    @Async
    public void sendWaitlistNotificationEmail(
            String toEmail,
            String fullName,
            String facilityName,
            String unitTypeName
    ) {
        String subject = "🔔 Có kho trống – " + facilityName;
        String content = """
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                  <div style="background: linear-gradient(135deg, #1E3C72, #2A5298); padding: 24px; text-align:center;">
                    <h2 style="color:white; margin:0;">🔔 Thông báo từ Store Hub</h2>
                  </div>
                  <div style="padding:24px; background:#fff;">
                    <p>Xin chào <strong>%s</strong>,</p>
                    <p>Tin vui! Đã có kho trống tại cơ sở bạn đang chờ:</p>
                    <ul>
                      <li><strong>Cơ sở:</strong> %s</li>
                      <li><strong>Loại kho:</strong> %s</li>
                    </ul>
                    <p>Vui lòng mở ứng dụng Store Hub và đặt chỗ <strong>ngay bây giờ</strong> trước khi kho được người khác đặt.</p>
                    <p style="color:#9ca3af; font-size:12px;">Email này được gửi tự động. Nếu bạn đã đặt chỗ thành công, hãy bỏ qua email này.</p>
                  </div>
                </div>
                """.formatted(fullName, facilityName, unitTypeName);

        sendHtmlEmail(toEmail, subject, content);
    }


    private void sendHtmlEmail(String to, String subject, String htmlContent) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(htmlContent, true);
            mailSender.send(message);
            log.info("Email sent to: {}", to);
        } catch (MessagingException e) {
            log.error("Failed to send email to: {}", to, e);
            throw new RuntimeException("Failed to send email", e);
        }
    }
}