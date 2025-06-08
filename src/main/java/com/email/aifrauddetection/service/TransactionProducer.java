package com.email.aifrauddetection.service;

import com.email.aifrauddetection.model.Customer;
import com.email.aifrauddetection.model.Transaction;
import com.email.aifrauddetection.repository.CustomerRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Random;

@Service
public class TransactionProducer {
    private static final Logger logger = LoggerFactory.getLogger(TransactionProducer.class);

    private static final String TOPIC = "transactions";
    private final EmbeddingGenerator embeddingGenerator;
    private final KafkaTemplate<String, Transaction> kafkaTemplate;
    private List<Customer> customers;
    private final Random random = new Random();
    private final CustomerRepository customerRepository;

    public TransactionProducer(KafkaTemplate<String, Transaction> kafkaTemplate, EmbeddingGenerator embeddingGenerator, CustomerRepository customerRepository) {
        this.kafkaTemplate = kafkaTemplate;
        this.embeddingGenerator = embeddingGenerator;
        this.customerRepository = customerRepository;
    }

    @PostConstruct
    public void loadCustomers() {
        customers = customerRepository.findAll();
        if (customers.isEmpty()) {
            logger.error("Warning: No customers found! Transactions may fail.");
        } else {
            logger.info("Cached {} customers for transaction generation.", customers.size());
        }
    }

    @Scheduled(fixedRate = 100)
    public void generateAndSendTransaction() {
        if (customers == null || customers.isEmpty()) {
            logger.error("No customers available. Skipping transaction generation.");
            return;
        }
        Transaction transaction = Transaction.generateRandom(customers.get(random.nextInt(customers.size())));
        String embeddingText = transaction.generateEmbeddingText();
        transaction.setEmbedding(embeddingGenerator.getEmbedding(embeddingText));
        kafkaTemplate.send(TOPIC, transaction.getTransactionId(), transaction);
        logger.info("Transaction sent to topic {}", TOPIC);
    }
}