package com.storehub;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import java.time.ZoneId;
import java.util.TimeZone;

@SpringBootApplication
@EnableScheduling
@EnableAsync
public class StoreHubApplication {

    // Booking, payment, refund SLA and JPA audit timestamps use LocalDateTime.
    // Pin their JVM clock to the same business zone as VNPay and the overdue job.
    static {
        configureBusinessTimeZone();
    }

    public static void configureBusinessTimeZone() {
        TimeZone.setDefault(TimeZone.getTimeZone(ZoneId.of("Asia/Ho_Chi_Minh")));
    }

    public static void main(String[] args) {
        // Tự động load biến môi trường từ .env
        Dotenv dotenv = Dotenv.configure().ignoreIfMissing().load();
        dotenv.entries().forEach(entry -> {
            // Explicit environment variables (including deployment secrets) take precedence.
            if (System.getenv(entry.getKey()) == null && System.getProperty(entry.getKey()) == null) {
                System.setProperty(entry.getKey(), entry.getValue());
            }
        });

        SpringApplication.run(StoreHubApplication.class, args);
    }
}