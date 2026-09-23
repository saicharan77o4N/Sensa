package com.example.sensa

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.SimpleDateFormat
import java.util.Date
import java.util.LinkedHashMap
import java.util.Locale
import java.util.TimeZone

/** Receives newly posted Android notifications after the user grants listener access. */
class SensaNotificationListenerService : NotificationListenerService() {
    private val recentNotificationFingerprints = LinkedHashMap<String, Unit>()

    override fun onNotificationPosted(statusBarNotification: StatusBarNotification) {
        val notification = statusBarNotification.notification
        val packageName = statusBarNotification.packageName
        val title = notification.extras.getCharSequence(Notification.EXTRA_TITLE).asSafeText()
        val content = notificationContent(notification)

        val capturedNotification = mapOf(
            "id" to statusBarNotification.key,
            "packageName" to packageName,
            "appName" to applicationNameFor(packageName),
            "title" to title,
            "content" to content,
            "timestamp" to formatTimestamp(statusBarNotification.postTime),
        )

        if (isDuplicate(capturedNotification)) {
            return
        }

        NotificationEventDispatcher.dispatch(capturedNotification)
    }

    private fun notificationContent(notification: Notification): String {
        val extras = notification.extras
        return extras.getCharSequence(Notification.EXTRA_BIG_TEXT).asSafeText()
            .ifEmpty { extras.getCharSequence(Notification.EXTRA_TEXT).asSafeText() }
            .ifEmpty { extras.getCharSequence(Notification.EXTRA_SUB_TEXT).asSafeText() }
    }

    private fun applicationNameFor(packageName: String): String = try {
        packageManager.getApplicationInfo(packageName, 0)
            .loadLabel(packageManager)
            .asSafeText()
            .ifEmpty { packageName }
    } catch (_: Exception) {
        packageName
    }

    /** Ignores repeated callbacks carrying exactly the same notification payload. */
    private fun isDuplicate(notification: Map<String, String>): Boolean {
        val fingerprint = listOf(
            notification.getValue("id"),
            notification.getValue("title"),
            notification.getValue("content"),
            notification.getValue("timestamp"),
        ).joinToString(separator = "|")

        synchronized(recentNotificationFingerprints) {
            if (recentNotificationFingerprints.containsKey(fingerprint)) {
                return true
            }

            recentNotificationFingerprints[fingerprint] = Unit
            if (recentNotificationFingerprints.size > MAX_RECENT_FINGERPRINTS) {
                val oldestFingerprint = recentNotificationFingerprints.entries.first().key
                recentNotificationFingerprints.remove(oldestFingerprint)
            }
            return false
        }
    }

    private fun formatTimestamp(postTime: Long): String {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(postTime))
    }

    private fun CharSequence?.asSafeText(): String = this?.toString()?.trim().orEmpty()

    private companion object {
        const val MAX_RECENT_FINGERPRINTS = 200
    }
}
