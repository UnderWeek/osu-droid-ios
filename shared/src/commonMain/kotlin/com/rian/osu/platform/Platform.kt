package com.rian.osu.platform

/**
 * Platform-specific logging abstraction.
 */
expect object PlatformLog {
    fun debug(tag: String, message: String)
    fun error(tag: String, message: String)
    fun warn(tag: String, message: String)
    fun info(tag: String, message: String)
}

/**
 * Platform-specific color representation.
 * Stores ARGB color as a 32-bit integer.
 */
data class PlatformColor(
    val red: Int,
    val green: Int,
    val blue: Int,
    val alpha: Int = 255
) {
    val argb: Int
        get() = (alpha shl 24) or (red shl 16) or (green shl 8) or blue

    companion object {
        fun fromARGB(argb: Int) = PlatformColor(
            red = (argb shr 16) and 0xFF,
            green = (argb shr 8) and 0xFF,
            blue = argb and 0xFF,
            alpha = (argb shr 24) and 0xFF
        )

        fun fromRGB(r: Int, g: Int, b: Int) = PlatformColor(r, g, b)
    }
}

/**
 * Platform-specific toast/notification logging.
 */
expect object PlatformToast {
    fun showText(message: String, duration: Long = 2000)
    fun showError(message: String)
}

/**
 * Platform-specific string table for localized strings.
 */
expect object PlatformStrings {
    fun get(key: String): String
    fun format(key: String, vararg args: Any): String
}

/**
 * Platform-specific file I/O operations.
 */
expect object PlatformFileIO {
    fun readLines(path: String): List<String>
    fun readBytes(path: String): ByteArray
    fun exists(path: String): Boolean
    fun listFiles(path: String): List<String>
    fun getFileSize(path: String): Long
}
