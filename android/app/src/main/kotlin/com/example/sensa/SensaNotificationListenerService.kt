package com.example.sensa

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.text.SimpleDateFormat
import java.util.Date
import java.util.LinkedHashMap
import java.util.Locale
import java.util.TimeZone

/** Receives Android notifications after the user grants listener access. */
class SensaNotificationListenerService : NotificationListenerService() {

    /**
     * Maps Android's stable notification key to the Sensa notification
     * occurrence ID currently being used for that active notification.
     *
     * This lets notification updates modify the same Sensa notification
     * instead of creating a new one.
     */
    private val activeNotificationIds = LinkedHashMap<String, String>()

    private val recentNotificationFingerprints = LinkedHashMap<String, Unit>()

    override fun onNotificationPosted(
        statusBarNotification: StatusBarNotification,
    ) {
        val notification = statusBarNotification.notification
        val packageName = statusBarNotification.packageName
        val notificationKey = statusBarNotification.key

        val title = notification.extras
            .getCharSequence(Notification.EXTRA_TITLE)
            .asSafeText()

        val content = notificationContent(notification)

        val notificationId = synchronized(activeNotificationIds) {
            activeNotificationIds.getOrPut(notificationKey) {
                "${statusBarNotification.packageName}_${statusBarNotification.postTime}_${statusBarNotification.id}"
            }
        }

        val capturedNotification = mapOf(
            "id" to notificationId,
            "notificationKey" to notificationKey,
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

    override fun onNotificationRemoved(
        statusBarNotification: StatusBarNotification,
    ) {
        val notificationKey = statusBarNotification.key

        synchronized(activeNotificationIds) {
            activeNotificationIds.remove(notificationKey)
        }

        debugLog(
            "Removed notification key: $notificationKey",
        )
    }

    private fun notificationContent(notification: Notification): String {
        val extras = notification.extras

        return extras
            .getCharSequence(Notification.EXTRA_BIG_TEXT)
            .asSafeText()
            .ifEmpty {
                extras
                    .getCharSequence(Notification.EXTRA_TEXT)
                    .asSafeText()
            }
            .ifEmpty {
                extras
                    .getCharSequence(Notification.EXTRA_SUB_TEXT)
                    .asSafeText()
            }
    }

    private fun applicationNameFor(packageName: String): String = try {
        packageManager
            .getApplicationInfo(packageName, 0)
            .loadLabel(packageManager)
            .asSafeText()
            .ifEmpty { packageName }
    } catch (_: Exception) {
        packageName
    }

    /**
     * Ignores repeated callbacks carrying exactly the same payload.
     *
     * The notification key is used instead of the occurrence ID because
     * Android may update the post time while keeping the same notification.
     */
    private fun isDuplicate(
        notification: Map<String, String>,
    ): Boolean {
        val fingerprint = listOf(
            notification.getValue("notificationKey"),
            notification.getValue("title"),
            notification.getValue("content"),
        ).joinToString(separator = "|")

        synchronized(recentNotificationFingerprints) {
            if (recentNotificationFingerprints.containsKey(fingerprint)) {
                return true
            }

            recentNotificationFingerprints[fingerprint] = Unit

            if (
                recentNotificationFingerprints.size >
                MAX_RECENT_FINGERPRINTS
            ) {
                val oldestFingerprint =
                    recentNotificationFingerprints.entries.first().key

                recentNotificationFingerprints.remove(oldestFingerprint)
            }

            return false
        }
    }

    private fun formatTimestamp(postTime: Long): String {
        return SimpleDateFormat(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            Locale.US,
        ).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(postTime))
    }

    private fun debugLog(message: String) {
        android.util.Log.d(
            "SENSA_NOTIFICATION",
            message,
        )
    }

    private fun CharSequence?.asSafeText(): String =
        this?.toString()?.trim().orEmpty()

    private companion object {
        const val MAX_RECENT_FINGERPRINTS = 200
    }
}