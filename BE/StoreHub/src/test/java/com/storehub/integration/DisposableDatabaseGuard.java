package com.storehub.integration;

import org.springframework.context.ApplicationContextInitializer;
import org.springframework.context.ConfigurableApplicationContext;

/** Runs before Flyway or seed users can touch the database. */
public class DisposableDatabaseGuard implements ApplicationContextInitializer<ConfigurableApplicationContext> {
    @Override
    public void initialize(ConfigurableApplicationContext context) {
        String url = context.getEnvironment().getProperty("DB_URL", "");
        if (!url.matches("jdbc:postgresql://[^/]+/storehub_it_[A-Za-z0-9_]+(?:\\?.*)?")) {
            throw new IllegalStateException("STOREHUB_INTEGRATION_TEST requires a disposable DB named storehub_it_*");
        }
    }
}
