package com.email.aifrauddetection.config;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import org.bson.Document;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
@Configuration
public class MongoDBConfig {
    private static final String DATABASE_NAME = "fraud";
    private static final String TRANSACTIONS_COLLECTION = "transactions";
    @Bean
    public MongoDatabase fraudDatabase(MongoClient mongoClient) {
        return mongoClient.getDatabase(DATABASE_NAME);
    }
    @Bean
    public MongoCollection<Document> transactionsCollection(MongoDatabase fraudDatabase) {
        return fraudDatabase.getCollection(TRANSACTIONS_COLLECTION);
    }
}
