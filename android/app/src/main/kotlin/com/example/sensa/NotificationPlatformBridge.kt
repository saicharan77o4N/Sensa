package com.example.sensa

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Channel names and dispatching shared by the activity and notification listener. */
object NotificationPlatformChannels {
    const val eventChannel = "com.example.sensa/notifications"
    const val methodChannel = "com.example.sensa/notification_access"
}

/**
 * Delivers live notification events to the currently running Flutter engine.
 *
 * Milestone 1 intentionally does not retain events when Flutter is not running;
 * local persistence will be added in a later milestone.
 */
object NotificationEventDispatcher {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun dispatch(notification: Map<String, String>) {
        mainHandler.post {
            eventSink?.success(notification)
        }
    }
}
