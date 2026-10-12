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
@Async
public void sendPasswordResetEmail(String toEmail, String fullName, String resetToken) {

    String resetLink = "storehub://reset-password?token="
            + java.net.URLEncoder.encode(resetToken, java.nio.charset.StandardCharsets.UTF_8);

    String subject = "🔐 Đặt lại mật khẩu – Store Hub";

    String content = """
            <!DOCTYPE html>
            <html lang="vi">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Đặt lại mật khẩu - Store Hub</title>
            </head>

            <body style="margin:0; padding:0; background-color:#f3f6fb; font-family:Arial, Helvetica, sans-serif; color:#1f2937;">

                <div style="width:100%%; padding:40px 16px; box-sizing:border-box;">

                    <div style="max-width:600px; margin:0 auto;">

                        <!-- Header -->
                        <div style="
                            background:linear-gradient(135deg, #1E3C72, #2A5298);
                            border-radius:16px 16px 0 0;
                            padding:32px 24px;
                            text-align:center;
                        ">
                            <div style="
                                display:inline-block;
                                background:rgba(255,255,255,0.15);
                                border-radius:14px;
                                padding:12px 16px;
                                margin-bottom:16px;
                            ">
                                <span style="font-size:28px;">🔐</span>
                            </div>

                            <h1 style="
                                margin:0;
                                color:#ffffff;
                                font-size:24px;
                                font-weight:700;
                            ">
                                Đặt lại mật khẩu
                            </h1>

                            <p style="
                                margin:10px 0 0;
                                color:rgba(255,255,255,0.85);
                                font-size:14px;
                            ">
                                Store Hub – Kho lưu trữ thông minh
                            </p>
                        </div>


                        <!-- Main Content -->
                        <div style="
                            background:#ffffff;
                            padding:36px 32px;
                            border-left:1px solid #e5e7eb;
                            border-right:1px solid #e5e7eb;
                        ">

                            <p style="
                                margin:0 0 18px;
                                font-size:16px;
                                line-height:1.6;
                            ">
                                Xin chào <strong>%s</strong>,
                            </p>

                            <p style="
                                margin:0 0 20px;
                                font-size:15px;
                                line-height:1.7;
                                color:#4b5563;
                            ">
                                Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản
                                <strong>Store Hub</strong> của bạn.
                            </p>

                            <div style="
                                background:#f0f5ff;
                                border:1px solid #dbe7ff;
                                border-radius:12px;
                                padding:18px;
                                margin:24px 0;
                            ">
                                <p style="
                                    margin:0;
                                    color:#374151;
                                    font-size:14px;
                                    line-height:1.6;
                                ">
                                    ⏱️ Liên kết đặt lại mật khẩu này sẽ
                                    <strong>hết hạn sau 15 phút</strong>.
                                    Vì lý do bảo mật, vui lòng không chia sẻ liên kết này
                                    với người khác.
                                </p>
                            </div>

                            <!-- CTA -->
                            <div style="text-align:center; margin:30px 0;">
                                <a href="%s"
                                   style="
                                       display:inline-block;
                                       background:linear-gradient(135deg, #1E3C72, #2A5298);
                                       color:#ffffff;
                                       text-decoration:none;
                                       padding:14px 30px;
                                       border-radius:8px;
                                       font-size:15px;
                                       font-weight:bold;
                                   ">
                                    🔑 Đặt lại mật khẩu
                                </a>
                            </div>

                            <p style="
                                margin:24px 0 8px;
                                font-size:13px;
                                color:#6b7280;
                                line-height:1.6;
                            ">
                                Nếu nút phía trên không hoạt động, bạn có thể sao chép
                                Nếu ứng dụng email không mở được liên kết, sao chép mã dưới đây
                                và chọn "I have a reset link" trong màn hình đăng nhập của app:
                            </p>

                            <div style="
                                background:#f9fafb;
                                border:1px solid #e5e7eb;
                                border-radius:8px;
                                padding:12px;
                                word-break:break-all;
                            ">
                                <a href="%s"
                                   style="
                                       color:#2563eb;
                                       font-size:12px;
                                       text-decoration:none;
                                   ">
                                    %s
                                </a>
                            </div>

                            <div style="
                                margin-top:28px;
                                padding-top:22px;
                                border-top:1px solid #e5e7eb;
                            ">
                                <p style="
                                    margin:0;
                                    font-size:13px;
                                    color:#6b7280;
                                    line-height:1.6;
                                ">
                                    🔒 Nếu bạn không yêu cầu đặt lại mật khẩu,
                                    bạn có thể bỏ qua email này. Tài khoản của bạn
                                    vẫn an toàn.
                                </p>
                            </div>

                        </div>


                        <!-- Footer -->
                        <div style="
                            background:#f9fafb;
                            border:1px solid #e5e7eb;
                            border-top:none;
                            border-radius:0 0 16px 16px;
                            padding:22px 24px;
                            text-align:center;
                        ">
                            <p style="
                                margin:0 0 6px;
                                color:#374151;
                                font-size:13px;
                                font-weight:bold;
                            ">
                                Store Hub Platform
                            </p>

                            <p style="
                                margin:0;
                                color:#9ca3af;
                                font-size:12px;
                            ">
                                Kho lưu trữ thông minh · © Store Hub
                            </p>
                        </div>

                    </div>

                </div>

            </body>
            </html>
            """.formatted(
            fullName,
            resetLink,
            resetLink,
            resetToken
    );

    sendHtmlEmail(toEmail, subject, content);
}


    @Override
@Async
public void sendWelcomeEmail(String toEmail, String fullName) {

    String loginLink = frontendUrl + "/login";

    String subject = "🎉 Chào mừng bạn đến với Store Hub!";

    String content = """
            <!DOCTYPE html>
            <html lang="vi">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Chào mừng đến với Store Hub</title>
            </head>

            <body style="margin:0; padding:0; background-color:#f3f6fb; font-family:Arial, Helvetica, sans-serif; color:#1f2937;">

                <div style="width:100%%; padding:40px 16px; box-sizing:border-box;">

                    <div style="max-width:600px; margin:0 auto;">

                        <!-- Header -->
                        <div style="
                            background:linear-gradient(135deg, #1E3C72, #2A5298);
                            border-radius:16px 16px 0 0;
                            padding:38px 24px;
                            text-align:center;
                        ">

                            <div style="
                                display:inline-block;
                                background:rgba(255,255,255,0.15);
                                border-radius:50%%;
                                width:70px;
                                height:70px;
                                line-height:70px;
                                margin-bottom:18px;
                            ">
                                <span style="font-size:34px;">📦</span>
                            </div>

                            <h1 style="
                                margin:0;
                                color:#ffffff;
                                font-size:26px;
                                font-weight:700;
                            ">
                                Chào mừng đến với Store Hub!
                            </h1>

                            <p style="
                                margin:10px 0 0;
                                color:rgba(255,255,255,0.85);
                                font-size:14px;
                            ">
                                Kho lưu trữ thông minh dành cho bạn
                            </p>

                        </div>


                        <!-- Main Content -->
                        <div style="
                            background:#ffffff;
                            padding:36px 32px;
                            border-left:1px solid #e5e7eb;
                            border-right:1px solid #e5e7eb;
                        ">

                            <p style="
                                margin:0 0 18px;
                                font-size:16px;
                                line-height:1.6;
                            ">
                                Xin chào <strong>%s</strong> 👋
                            </p>

                            <p style="
                                margin:0 0 20px;
                                font-size:15px;
                                line-height:1.7;
                                color:#4b5563;
                            ">
                                Chúc mừng! Tài khoản <strong>Store Hub</strong> của bạn
                                đã được tạo thành công.
                            </p>


                            <!-- Success Box -->
                            <div style="
                                background:#ecfdf5;
                                border:1px solid #bbf7d0;
                                border-radius:12px;
                                padding:18px;
                                margin:24px 0;
                            ">
                                <p style="
                                    margin:0;
                                    color:#166534;
                                    font-size:14px;
                                    line-height:1.6;
                                ">
                                    ✅ Tài khoản của bạn đã sẵn sàng.
                                    Bạn có thể đăng nhập và bắt đầu tìm kiếm
                                    không gian lưu trữ phù hợp.
                                </p>
                            </div>


                            <!-- Features -->
                            <div style="margin:28px 0;">

                                <div style="
                                    display:flex;
                                    margin-bottom:18px;
                                ">
                                    <div style="
                                        width:42px;
                                        height:42px;
                                        background:#eef4ff;
                                        border-radius:10px;
                                        text-align:center;
                                        line-height:42px;
                                        margin-right:12px;
                                        flex-shrink:0;
                                    ">
                                        📦
                                    </div>

                                    <div>
                                        <p style="
                                            margin:0 0 4px;
                                            font-size:14px;
                                            font-weight:bold;
                                            color:#1f2937;
                                        ">
                                            Tìm kho phù hợp
                                        </p>

                                        <p style="
                                            margin:0;
                                            font-size:13px;
                                            color:#6b7280;
                                            line-height:1.5;
                                        ">
                                            Khám phá các cơ sở và lựa chọn kho
                                            phù hợp với nhu cầu của bạn.
                                        </p>
                                    </div>
                                </div>


                                <div style="
                                    display:flex;
                                    margin-bottom:18px;
                                ">
                                    <div style="
                                        width:42px;
                                        height:42px;
                                        background:#eef4ff;
                                        border-radius:10px;
                                        text-align:center;
                                        line-height:42px;
                                        margin-right:12px;
                                        flex-shrink:0;
                                    ">
                                        🔒
                                    </div>

                                    <div>
                                        <p style="
                                            margin:0 0 4px;
                                            font-size:14px;
                                            font-weight:bold;
                                            color:#1f2937;
                                        ">
                                            Quản lý kho an toàn
                                        </p>

                                        <p style="
                                            margin:0;
                                            font-size:13px;
                                            color:#6b7280;
                                            line-height:1.5;
                                        ">
                                            Theo dõi thông tin đặt chỗ và
                                            kho đang thuê của bạn.
                                        </p>
                                    </div>
                                </div>


                                <div style="
                                    display:flex;
                                ">
                                    <div style="
                                        width:42px;
                                        height:42px;
                                        background:#eef4ff;
                                        border-radius:10px;
                                        text-align:center;
                                        line-height:42px;
                                        margin-right:12px;
                                        flex-shrink:0;
                                    ">
                                        💳
                                    </div>

                                    <div>
                                        <p style="
                                            margin:0 0 4px;
                                            font-size:14px;
                                            font-weight:bold;
                                            color:#1f2937;
                                        ">
                                            Thanh toán thuận tiện
                                        </p>

                                        <p style="
                                            margin:0;
                                            font-size:13px;
                                            color:#6b7280;
                                            line-height:1.5;
                                        ">
                                            Quản lý các khoản thanh toán
                                            và giao dịch trực tiếp trên hệ thống.
                                        </p>
                                    </div>
                                </div>

                            </div>


                            <!-- CTA -->
                            <div style="text-align:center; margin:32px 0 24px;">

                                <a href="%s"
                                   style="
                                       display:inline-block;
                                       background:linear-gradient(135deg, #1E3C72, #2A5298);
                                       color:#ffffff;
                                       text-decoration:none;
                                       padding:14px 32px;
                                       border-radius:8px;
                                       font-size:15px;
                                       font-weight:bold;
                                   ">
                                    🚀 Đăng nhập Store Hub
                                </a>

                            </div>


                            <p style="
                                margin:0;
                                text-align:center;
                                font-size:13px;
                                color:#9ca3af;
                            ">
                                Bắt đầu trải nghiệm Store Hub ngay hôm nay.
                            </p>

                        </div>


                        <!-- Footer -->
                        <div style="
                            background:#f9fafb;
                            border:1px solid #e5e7eb;
                            border-top:none;
                            border-radius:0 0 16px 16px;
                            padding:22px 24px;
                            text-align:center;
                        ">

                            <p style="
                                margin:0 0 6px;
                                color:#374151;
                                font-size:13px;
                                font-weight:bold;
                            ">
                                Store Hub Platform
                            </p>

                            <p style="
                                margin:0;
                                color:#9ca3af;
                                font-size:12px;
                            ">
                                Kho lưu trữ thông minh · © Store Hub
                            </p>

                        </div>

                    </div>

                </div>

            </body>
            </html>
            """.formatted(
            fullName,
            loginLink
    );

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
