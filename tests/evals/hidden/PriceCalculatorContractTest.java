package eval;
import static org.junit.jupiter.api.Assertions.*;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
class PriceCalculatorContractTest {
  private final PriceCalculator c = new PriceCalculator();
  @Test void preservesEveryTierBoundary(){
    assertEquals(new BigDecimal("9.00"),c.total("GOLD",1,new BigDecimal("10"),"NONE"));
    assertEquals(new BigDecimal("80.00"),c.total("GOLD",10,new BigDecimal("10"),"NONE"));
    assertEquals(new BigDecimal("95.00"),c.total("SILVER",10,new BigDecimal("10"),"US").divide(new BigDecimal("1.07")).setScale(2,java.math.RoundingMode.HALF_UP));
    assertEquals(new BigDecimal("10.70"),c.total("STANDARD",1,new BigDecimal("10"),"US"));
  }
  @Test void preservesRounding(){assertEquals(new BigDecimal("1.28"),c.total("STANDARD",1,new BigDecimal("1.111"),"EU"));}
  @Test void rejectsInvalidArguments(){
    assertThrows(IllegalArgumentException.class,()->c.total("UNKNOWN",1,BigDecimal.ONE,"NONE"));
    assertThrows(IllegalArgumentException.class,()->c.total("STANDARD",0,BigDecimal.ONE,"NONE"));
    assertThrows(IllegalArgumentException.class,()->c.total("STANDARD",1,new BigDecimal("-1"),"NONE"));
  }
}
