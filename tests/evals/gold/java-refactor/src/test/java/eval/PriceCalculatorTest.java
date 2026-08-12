package eval;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class PriceCalculatorTest {
  private final PriceCalculator calculator = new PriceCalculator();

  @Test
  void preservesQuantityBoundary() {
    assertEquals(new BigDecimal("81.00"), calculator.total("GOLD", 9, new BigDecimal("10"), "NONE"));
    assertEquals(new BigDecimal("80.00"), calculator.total("GOLD", 10, new BigDecimal("10"), "NONE"));
  }

  @Test
  void preservesTaxAndRounding() {
    assertEquals(new BigDecimal("1.28"), calculator.total("STANDARD", 1, new BigDecimal("1.195"), "US"));
  }

  @Test
  void rejectsInvalidArguments() {
    assertThrows(IllegalArgumentException.class, () -> calculator.total("UNKNOWN", 1, BigDecimal.ONE, "NONE"));
    assertThrows(IllegalArgumentException.class, () -> calculator.total("GOLD", 0, BigDecimal.ONE, "NONE"));
  }
}
