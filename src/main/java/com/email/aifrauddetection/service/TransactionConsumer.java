package com.email.aifrauddetection.service;

import com.email.aifrauddetection.model.Transaction;
import com.email.aifrauddetection.repository.TransactionRepository;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class TransactionConsumer {
    private final TransactionRepository transactionRepository;

    public TransactionConsumer(TransactionRepository transactionRepository) {
        this.transactionRepository = transactionRepository;
    }

    @KafkaListener(topics = "transactions", groupId = "fraud-group")
    public void consumeTransaction(Transaction transaction) {
        transactionRepository.save(transaction);
    }
}
