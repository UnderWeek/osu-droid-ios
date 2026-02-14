package com.rian.osu.platform

import android.util.Log
import android.widget.Toast
import java.io.File

actual object PlatformLog {
    actual fun debug(tag: String, message: String) { Log.d(tag, message) }
    actual fun error(tag: String, message: String) { Log.e(tag, message) }
    actual fun warn(tag: String, message: String) { Log.w(tag, message) }
    actual fun info(tag: String, message: String) { Log.i(tag, message) }
}

actual object PlatformToast {
    actual fun showText(message: String, duration: Long) {
        // Delegate to ToastLogger in the Android app module
        println("[Toast] $message")
    }

    actual fun showError(message: String) {
        println("[Error] $message")
    }
}

actual object PlatformStrings {
    actual fun get(key: String): String = key
    actual fun format(key: String, vararg args: Any): String = key
}

actual object PlatformFileIO {
    actual fun readLines(path: String): List<String> = File(path).readLines()
    actual fun readBytes(path: String): ByteArray = File(path).readBytes()
    actual fun exists(path: String): Boolean = File(path).exists()
    actual fun listFiles(path: String): List<String> =
        File(path).listFiles()?.map { it.absolutePath } ?: emptyList()
    actual fun getFileSize(path: String): Long = File(path).length()
}
