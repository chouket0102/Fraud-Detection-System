package com.email.aifrauddetection.enums;

import java.util.List;
import java.util.Map;
import java.util.Random;

public enum Merchant {
    // Retail Merchants
    AMAZON, WALMART, BEST_BUY, TARGET, COSTCO, ETSY, EBAY, IKEA,

    // Tech Merchants
    APPLE, MICROSOFT, GOOGLE,

    // Grocery Merchants
    DUNNES_STORES, LIDL, TESCO;

    private static final Random RANDOM = new Random();

    private static final Map<Category, List<Merchant>> CATEGORY_MERCHANTS = Map.of(
            Category.RETAIL, List.of(AMAZON, WALMART, BEST_BUY, TARGET, COSTCO, ETSY, EBAY, IKEA),
            Category.TECH, List.of(APPLE, MICROSOFT, GOOGLE),
            Category.GROCERY, List.of(DUNNES_STORES, LIDL, TESCO)
    );

    public static Merchant getRandomMerchant(Category category) {
        List<Merchant> merchants = CATEGORY_MERCHANTS.get(category);
        return merchants.get(RANDOM.nextInt(merchants.size()));
    }
}