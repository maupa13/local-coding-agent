package eval;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Map;

public class PriceCalculator {
  private static final Map<String, BigDecimal[]> DISCOUNTS = Map.of(
      "GOLD", new BigDecimal[] {new BigDecimal("0.90"), new BigDecimal("0.80")},
      "SILVER", new BigDecimal[] {new BigDecimal("0.95"), new BigDecimal("0.90")},
      "STANDARD", new BigDecimal[] {BigDecimal.ONE, BigDecimal.ONE});
  private static final Map<String, BigDecimal> TAXES = Map.of(
      "EU", new BigDecimal("1.20"),
      "US", new BigDecimal("1.07"),
      "NONE", BigDecimal.ONE);

  public BigDecimal total(String tier, int quantity, BigDecimal unitPrice, String region) {
    validate(tier, quantity, unitPrice, region);
    BigDecimal[] rates = DISCOUNTS.get(tier);
    BigDecimal discount = rates[quantity >= 10 ? 1 : 0];
    return unitPrice.multiply(BigDecimal.valueOf(quantity))
        .multiply(discount)
        .multiply(TAXES.get(region))
        .setScale(2, RoundingMode.HALF_UP);
  }

  private static void validate(
      String tier, int quantity, BigDecimal unitPrice, String region) {
    if (tier == null || region == null || unitPrice == null || quantity <= 0
        || unitPrice.signum() < 0 || !DISCOUNTS.containsKey(tier) || !TAXES.containsKey(region)) {
      throw new IllegalArgumentException();
    }
  }
}
