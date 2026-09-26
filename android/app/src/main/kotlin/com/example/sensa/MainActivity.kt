package com.example.sensa

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NotificationPlatformChannels.eventChannel,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                NotificationEventDispatcher.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                NotificationEventDispatcher.setEventSink(null)
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NotificationPlatformChannels.methodChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> result.success(isNotificationAccessGranted())
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "openNotificationApp" -> {
                    val packageName = call.argument<String>("packageName")

                    if (packageName.isNullOrBlank()) {
                        result.error(
                            "INVALID_PACKAGE",
                            "Package name is missing.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                        ?: Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                            setPackage(packageName)
                        }

                    val resolvedIntent = packageManager.resolveActivity(
                        intent,
                        0,
                    )

                    if (resolvedIntent == null) {
                        result.error(
                            "APP_NOT_FOUND",
                            "Could not resolve a launchable activity for $packageName.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    intent.component = resolvedIntent.activityInfo?.let {
                        ComponentName(
                            it.packageName,
                            it.name,
                        )
                    }

                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                    try {
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "APP_LAUNCH_FAILED",
                            "Could not launch $packageName: ${error.message}",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val expectedComponent = ComponentName(this, SensaNotificationListenerService::class.java)

        return enabledListeners.split(':')
            .mapNotNull(ComponentName::unflattenFromString)
            .any { component ->
                component.packageName == packageName &&
                    component.className == expectedComponent.className
            }
    }
}
