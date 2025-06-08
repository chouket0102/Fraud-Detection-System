package com.email.aifrauddetection.service;

import com.mongodb.client.*;
import com.mongodb.client.model.Aggregates;
import com.mongodb.client.model.Filters;
import com.mongodb.client.model.changestream.ChangeStreamDocument;
import org.bson.Document;
import org.bson.conversions.Bson;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;

@Service
public class TransactionChangeStreamListener {
    private static final Logger logger = LoggerFactory.getLogger(TransactionChangeStreamListener.class);

    private final TransactionVectorSearchService vectorSearchService;
    private final ExecutorService executorService = Executors.newSingleThreadExecutor(); // Keeps it synchronous
    private final MongoCollection<Document> transactionsCollection;

    public TransactionChangeStreamListener(TransactionVectorSearchService vectorSearchService, MongoCollection<Document> transactionsCollection) {
        this.transactionsCollection = transactionsCollection;
        this.vectorSearchService = vectorSearchService;
    }

    public void startListening() {
        executorService.submit(() -> {
            // Filter to only listen for INSERT operations
            List<Bson> pipeline = List.of(Aggregates.match(Filters.eq("operationType", "insert")));

            try (MongoCursor<ChangeStreamDocument<Document>> cursor = transactionsCollection.watch(pipeline).iterator()) {
                while (cursor.hasNext()) {
                    ChangeStreamDocument<Document> change = cursor.next();
                    Document transactionDoc = change.getFullDocument();

                    if (transactionDoc != null) {
                        logger.info("New transaction detected: {}", transactionDoc.getString("transactionId"));

                        List<Double> embedding = transactionDoc.getList("embedding", Double.class);
                        if (embedding != null) {
                            logger.info("Performing vector search");
                            vectorSearchService.evaluateTransactionFraud(transactionDoc);
                        } else {
                            logger.error("Warning: Transaction does not contain an embedding field.");
                        }
                    }
                }
            }
        });
    }

}