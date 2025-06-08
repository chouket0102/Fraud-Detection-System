package com.email.aifrauddetection.service;

import com.email.aifrauddetection.model.Customer;
import com.email.aifrauddetection.model.Transaction;
import com.email.aifrauddetection.repository.CustomerRepository;
import com.email.aifrauddetection.repository.TransactionRepository;
import com.mongodb.client.MongoCollection;
import jakarta.annotation.PostConstruct;
import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class TransactionSeeder {
    private static final Logger logger = LoggerFactory.getLogger(TransactionSeeder.class);
    private final CustomerRepository customerRepository;
    private final EmbeddingGenerator embeddingGenerator;
    private final TransactionRepository transactionRepository;
    private final TransactionChangeStreamListener transactionChangeStreamListener;
    private final MongoCollection<Document> transactionsCollection;

    public TransactionSeeder(CustomerRepository customerRepository,
                             EmbeddingGenerator embeddingGenerator, TransactionRepository transactionRepository,
                             TransactionChangeStreamListener transactionChangeStreamListener, MongoCollection<Document> transactionsCollection) {
        this.transactionsCollection = transactionsCollection;
        this.transactionRepository = transactionRepository;
        this.customerRepository = customerRepository;
        this.embeddingGenerator = embeddingGenerator;
        this.transactionChangeStreamListener = transactionChangeStreamListener;
    }

    @PostConstruct
    public void seedTransactions() {
        if (transactionsCollection.countDocuments() > 0) {
            logger.info("Transactions already seeded.");
            return;
        }

        List<Customer> customers = customerRepository.findAll();
        List<Transaction> transactions = new ArrayList<>();

        for (Customer customer : customers) {
            for (int i = 0; i < 10; i++) {
                Transaction transaction = Transaction.generateRandom(customer);
                String embeddingText = transaction.generateEmbeddingText();
                float[] embedding = embeddingGenerator.getEmbedding(embeddingText);
                transaction.setEmbedding(embedding);
                transactions.add(transaction);
            }
        }

        transactionRepository.saveAll(transactions);
        logger.info("Seeded 100 transactions.");

        transactionChangeStreamListener.startListening();
        logger.info("Change Stream Listener Started.");
    }
}
