package com.storehub;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ContextConfiguration;
import com.storehub.integration.DisposableDatabaseGuard;
import com.storehub.scheduler.RefundDispatcher;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest
@ContextConfiguration(initializers = DisposableDatabaseGuard.class)
// Chỉ chạy khi đã cấu hình PostgreSQL và các biến môi trường cho integration test.
@EnabledIfEnvironmentVariable(
        named = "STOREHUB_INTEGRATION_TEST",
        matches = "true"
)
class StoreHubApplicationTests {
    // contextLoads must not contact the payment gateway through a scheduled job.
    @MockitoBean RefundDispatcher refundDispatcher;

    @Test
    void contextLoads() {
    }
}
