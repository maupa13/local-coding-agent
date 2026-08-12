package eval

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class SlugifierTest {
    @Test fun normalizesWordsAndSeparators() = assertEquals("hello-world", Slugifier.slug("  Hello, WORLD! "))
    @Test fun collapsesSeparatorRuns() = assertEquals("a-b", Slugifier.slug("a___ --- b"))
    @Test fun acceptsDigits() = assertEquals("release-42", Slugifier.slug("Release 42"))
    @Test fun rejectsNullAndBlank() {
        assertFailsWith<IllegalArgumentException> { Slugifier.slug(null) }
        assertFailsWith<IllegalArgumentException> { Slugifier.slug("   ") }
        assertFailsWith<IllegalArgumentException> { Slugifier.slug("---") }
    }
}
