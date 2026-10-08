package com.storehub;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
// Chỉ chạy khi đã cấu hình PostgreSQL và các biến môi trường cho integration test.
@EnabledIfEnvironmentVariable(
        named = "STOREHUB_INTEGRATION_TEST",
        matches = "true"
)
class StoreHubApplicationTests {

    @Test
    void contextLoads() {
    }
}