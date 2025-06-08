package com.email.aifrauddetection.service;

import com.email.aifrauddetection.enums.Category;
import com.email.aifrauddetection.enums.Currency;
import com.email.aifrauddetection.enums.Merchant;
import com.email.aifrauddetection.model.Customer;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CustomerSeeder {
    private static final Logger logger = LoggerFactory.getLogger(CustomerSeeder.class);
    private final MongoTemplate mongoTemplate;
    //Using MongoTemplate, we can directly check if data exists before inserting
    public CustomerSeeder(MongoTemplate mongoTemplate) {
        this.mongoTemplate = mongoTemplate;
    }

    @PostConstruct
    public void seedCustomers() {
        if (mongoTemplate.getCollection("customers").countDocuments() > 0) {
            logger.info("Customers already exist. Skipping seed.");
            return;
        }

        List<Customer> customers = List.of(
                new Customer("user_1", List.of(Merchant.AMAZON, Merchant.BEST_BUY), List.of(Category.TECH, Category.RETAIL), 150.0, 30.0, Currency.USD),
                new Customer("user_2", List.of(Merchant.WALMART, Merchant.TARGET, Merchant.DUNNES_STORES), List.of(Category.RETAIL, Category.GROCERY), 80.0, 20.0, Currency.USD),
                new Customer("user_3", List.of(Merchant.APPLE, Merchant.MICROSOFT), List.of(Category.TECH), 250.0, 50.0, Currency.EUR),
                new Customer("user_4", List.of(Merchant.ETSY, Merchant.BEST_BUY), List.of(Category.RETAIL), 100.0, 25.0, Currency.EUR),
                new Customer("user_5", List.of(Merchant.ETSY, Merchant.EBAY), List.of(Category.RETAIL), 90.0, 20.0, Currency.GBP),
                new Customer("user_6", List.of(Merchant.TESCO, Merchant.DUNNES_STORES), List.of(Category.GROCERY), 40.0, 10.0, Currency.EUR),
                new Customer("user_7", List.of(Merchant.LIDL, Merchant.COSTCO), List.of(Category.GROCERY), 35.0, 8.0, Currency.EUR),
                new Customer("user_8",  List.of(Merchant.GOOGLE, Merchant.MICROSOFT), List.of(Category.TECH), 15.0, 5.0, Currency.USD),
                new Customer("user_9", List.of(Merchant.EBAY, Merchant.ETSY), List.of(Category.RETAIL), 60.0, 15.0, Currency.GBP),
                new Customer("user_10", List.of(Merchant.COSTCO, Merchant.IKEA), List.of(Category.RETAIL), 25.0, 7.0, Currency.GBP)
        );

        mongoTemplate.insertAll(customers);
        logger.info("Customers seeded successfully!");
    }
}