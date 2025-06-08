package com.email.aifrauddetection.repository;

import com.email.aifrauddetection.model.Customer;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CustomerRepository extends MongoRepository<Customer, String> {

}
