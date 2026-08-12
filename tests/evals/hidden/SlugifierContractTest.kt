package eval

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class SlugifierContractTest {
    @Test fun exactBoundaryAndLocaleIndependentContract() {
        assertEquals("i-42", Slugifier.slug("I / 42"))
        assertEquals("a", Slugifier.slug("---A---"))
    }

    @Test fun invalidContract() {
        assertFailsWith<IllegalArgumentException> { Slugifier.slug(null) }
        assertFailsWith<IllegalArgumentException> { Slugifier.slug("Ж") }
    }
}
