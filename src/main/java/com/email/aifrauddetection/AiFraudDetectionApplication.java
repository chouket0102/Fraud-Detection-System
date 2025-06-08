package com.email.aifrauddetection;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AiFraudDetectionApplication {

    public static void main(String[] args) {
        SpringApplication.run(AiFraudDetectionApplication.class, args);
    }

}
