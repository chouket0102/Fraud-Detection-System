package com.email.aifrauddetection.model;

import com.email.aifrauddetection.enums.Category;
import com.email.aifrauddetection.enums.Currency;
import com.email.aifrauddetection.enums.Merchant;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.List;
import java.util.Random;

@Document(collection = "customers")
public class Customer {
    @Id
    private String id;
    private final String userId;
    private final List<Merchant> merchants; // Trusted merchants
    private final List<Category> categories; // Trusted categories
    private final Double meanSpending;
    private final Double spendingStdDev;
    private final Currency preferredCurrency;

    public Customer(String userId, List<Merchant> merchants, List<Category> categories,
                    Double meanSpending, Double spendingStdDev, Currency preferredCurrency) {
        this.userId = userId;
        this.merchants = merchants;
        this.categories = categories;
        this.meanSpending = meanSpending;
        this.spendingStdDev = spendingStdDev;
        this.preferredCurrency = preferredCurrency;
    }

    public String getId() { return id; }
    public String getUserId() { return userId; }
    public List<Merchant> getMerchants() { return merchants; }
    public List<Category> getCategories() { return categories; }
    public Double getMeanSpending() { return meanSpending; }
    public Double getSpendingStdDev() { return spendingStdDev; }
    public Currency getPreferredCurrency() { return preferredCurrency; }

    public Category getFrequentCategory() {
        Random random = new Random();
        return categories.get(random.nextInt(categories.size()));
    }

    public Category getUnfrequentCategory() {
        // Get all categories from the enum
        List<Category> allCategories = List.of(Category.values());

        // Filter out frequent categories
        List<Category> infrequentCategories = allCategories.stream()
                .filter(category -> !categories.contains(category))
                .toList();

        // Pick a random category from the remaining ones
        Random random = new Random();
        return infrequentCategories.get(random.nextInt(infrequentCategories.size()));
    }

    public Currency getRandomSuspiciousCurrency() {
        // Get all categories from the enum
        List<Currency> allCurrency = List.of(Currency.values());

        // Filter out frequent categories
        List<Currency> infrequentCurrency = allCurrency.stream()
                .filter(currency -> !(preferredCurrency == currency)) // Exclude frequent ones
                .toList();

        // Pick a random category from the remaining ones
        Random random = new Random();
        return infrequentCurrency.get(random.nextInt(infrequentCurrency.size()));
    }
}