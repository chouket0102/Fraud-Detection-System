package com.email.aifrauddetection.repository;

import com.email.aifrauddetection.model.Transaction;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface TransactionRepository extends MongoRepository<Transaction,String> {
}
