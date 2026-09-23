import 'dart:async';

import 'package:flutter/material.dart';

import 'captured_notification.dart';
import 'notification_capture_service.dart';

void main() {
  runApp(const SensaApp());
}

class SensaApp extends StatelessWidget {
  const SensaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const NotificationInboxPage(),
    );
  }
}

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage>
    with WidgetsBindingObserver {
  final _captureService = NotificationCaptureService();
  final List<CapturedNotification> _notifications = [];
  StreamSubscription<CapturedNotification>? _notificationSubscription;

  bool _notificationAccessGranted = false;
  bool _checkingAccess = true;
  String? _captureError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationSubscription = _captureService.notifications.listen(
      _addNotification,
      onError: (Object error) {
        if (mounted) {
          setState(
            () => _captureError = 'Unable to receive notifications: $error',
          );
        }
      },
    );
    _refreshNotificationAccess();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationAccess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotificationAccess() async {
    try {
      final granted = await _captureService.isNotificationAccessGranted();
      if (mounted) {
        setState(() {
          _notificationAccessGranted = granted;
          _checkingAccess = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _checkingAccess = false;
          _captureError = 'Unable to check notification access: $error';
        });
      }
    }
  }

  Future<void> _openNotificationAccessSettings() async {
    try {
      await _captureService.openNotificationAccessSettings();
    } catch (error) {
      if (mounted) {
        setState(() => _captureError = 'Unable to open settings: $error');
      }
    }
  }

  void _addNotification(CapturedNotification notification) {
    if (!mounted) {
      return;
    }

    setState(() {
      _notifications.insert(0, notification);
      _captureError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensa'),
        actions: [
          IconButton(
            onPressed: _refreshNotificationAccess,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh notification access',
          ),
        ],
      ),
      body: Column(
        children: [
          _AccessStatusCard(
            granted: _notificationAccessGranted,
            checking: _checkingAccess,
            onOpenSettings: _openNotificationAccessSettings,
          ),
          if (_captureError case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _notifications.isEmpty
                ? const _EmptyNotificationList()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _NotificationListItem(
                        notification: _notifications[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccessStatusCard extends StatelessWidget {
  const _AccessStatusCard({
    required this.granted,
    required this.checking,
    required this.onOpenSettings,
  });

  final bool granted;
  final bool checking;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isReady = granted && !checking;

    return Card(
      margin: const EdgeInsets.all(16),
      color: isReady
          ? colors.secondaryContainer
          : colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isReady ? Icons.notifications_active : Icons.notifications_off,
              color: isReady
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checking
                        ? 'Checking notification access…'
                        : granted
                        ? 'Notification access is enabled'
                        : 'Notification access is not enabled',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    granted
                        ? 'New phone notifications will appear below while Sensa is running.'
                        : 'Enable access so Sensa can receive new Android notifications.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings),
                    label: Text(
                      granted
                          ? 'Open notification settings'
                          : 'Enable notification access',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationList extends StatelessWidget {
  const _EmptyNotificationList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'No new notifications yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'After access is enabled, send a notification from another app to see it here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  const _NotificationListItem({required this.notification});

  final CapturedNotification notification;

  @override
  Widget build(BuildContext context) {
    final title = notification.title.isEmpty ? 'No title' : notification.title;
    final content = notification.content.isEmpty
        ? 'No content'
        : notification.content;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.notifications)),
      title: Text(
        notification.appName.isEmpty
            ? notification.packageName
            : notification.appName,
      ),
      subtitle: Text(
        '$title\n$content',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Text(
        _formatTimestamp(notification.timestamp),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final localTime = timestamp.toLocal();
    return '${_twoDigits(localTime.hour)}:${_twoDigits(localTime.minute)}\n'
        '${_twoDigits(localTime.day)}/${_twoDigits(localTime.month)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
