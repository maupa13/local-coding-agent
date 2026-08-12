package eval

import java.util.Locale

object Slugifier {
    @JvmStatic
    fun slug(value: String?): String {
        require(!value.isNullOrBlank()) { "value must not be blank" }
        val slug = value.trim()
            .lowercase(Locale.ROOT)
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
        require(slug.isNotEmpty()) { "value must contain an ASCII alphanumeric character" }
        return slug
    }
}
