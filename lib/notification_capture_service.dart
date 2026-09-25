import 'package:flutter/services.dart';

import 'captured_notification.dart';

class NotificationCaptureService {
  static const _notificationEvents = EventChannel(
    'com.example.sensa/notifications',
  );
  static const _notificationAccess = MethodChannel(
    'com.example.sensa/notification_access',
  );

  Stream<CapturedNotification> get notifications => _notificationEvents
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map(
        (event) => CapturedNotification.fromPlatformMap(
          Map<Object?, Object?>.from(event as Map),
        ),
      );

  Future<bool> isNotificationAccessGranted() async {
    return await _notificationAccess.invokeMethod<bool>(
          'isNotificationAccessGranted',
        ) ??
        false;
  }

  Future<void> openNotificationAccessSettings() {
    return _notificationAccess.invokeMethod<void>(
      'openNotificationAccessSettings',
    );
  }
  Future<void> openNotificationApp(String packageName) {
    return _notificationAccess.invokeMethod<void>(
      'openNotificationApp',
      <String, dynamic>{
        'packageName': packageName,
      },
    );
  }
}
