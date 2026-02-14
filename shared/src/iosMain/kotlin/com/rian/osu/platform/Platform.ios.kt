package com.rian.osu.platform

import platform.Foundation.*

actual object PlatformLog {
    actual fun debug(tag: String, message: String) { NSLog("[$tag] DEBUG: $message") }
    actual fun error(tag: String, message: String) { NSLog("[$tag] ERROR: $message") }
    actual fun warn(tag: String, message: String) { NSLog("[$tag] WARN: $message") }
    actual fun info(tag: String, message: String) { NSLog("[$tag] INFO: $message") }
}

actual object PlatformToast {
    // iOS doesn't have native toast — handled by Swift UI layer
    actual fun showText(message: String, duration: Long) {
        NSLog("[Toast] $message")
    }

    actual fun showError(message: String) {
        NSLog("[Error] $message")
    }
}

actual object PlatformStrings {
    actual fun get(key: String): String {
        return NSBundle.mainBundle.localizedStringForKey(key, key, null)
    }

    actual fun format(key: String, vararg args: Any): String {
        val template = get(key)
        var result = template
        args.forEachIndexed { index, arg ->
            result = result.replace("{$index}", arg.toString())
        }
        return result
    }
}

actual object PlatformFileIO {
    actual fun readLines(path: String): List<String> {
        val content = NSString.stringWithContentsOfFile(path, NSUTF8StringEncoding, null) ?: return emptyList()
        return content.toString().split("\n")
    }

    actual fun readBytes(path: String): ByteArray {
        val data = NSData.dataWithContentsOfFile(path) ?: return ByteArray(0)
        return data.toByteArray()
    }

    actual fun exists(path: String): Boolean {
        return NSFileManager.defaultManager.fileExistsAtPath(path)
    }

    actual fun listFiles(path: String): List<String> {
        val contents = NSFileManager.defaultManager.contentsOfDirectoryAtPath(path, null) ?: return emptyList()
        @Suppress("UNCHECKED_CAST")
        return (contents as List<String>).map { "$path/$it" }
    }

    actual fun getFileSize(path: String): Long {
        val attrs = NSFileManager.defaultManager.attributesOfItemAtPath(path, null) ?: return 0
        return (attrs[NSFileSize] as? NSNumber)?.longValue ?: 0
    }
}

private fun NSData.toByteArray(): ByteArray {
    val size = this.length.toInt()
    val bytes = ByteArray(size)
    if (size > 0) {
        bytes.usePinned { pinned ->
            memcpy(pinned.addressOf(0), this.bytes, this.length)
        }
    }
    return bytes
}
