import 'dart:async';

import 'package:flutter/material.dart';

import 'captured_notification.dart';
import 'notification_capture_service.dart';
import 'notification_database.dart';
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
  final _database = NotificationDatabase.instance;
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
    _loadSavedNotifications();
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

  Future<void> _addNotification(CapturedNotification notification) async {
  try {
    await _database.insertNotification(notification);

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications.add(notification);
      _notifications.sort(
        (a, b) => b.timestamp.compareTo(a.timestamp),
      );
      _captureError = null;
    });
  } catch (error) {
    if (mounted) {
      setState(() {
        _captureError = 'Unable to save notification: $error';
      });
    }
  }
}
Map<String, List<CapturedNotification>> _groupNotificationsByApp() {
  final groups = <String, List<CapturedNotification>>{};

  for (final notification in _notifications) {
    final appName = notification.appName.isEmpty
        ? notification.packageName
        : notification.appName;

    groups.putIfAbsent(appName, () => []).add(notification);
  }

  return groups;
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
                  : _GroupedNotificationList(
                      groups: _groupNotificationsByApp(),
                    ),
            ),
        ],
      ),
    );
  }
  Future<void> _loadSavedNotifications() async {
  try {
    final savedNotifications = await _database.getNotifications();

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications
        ..clear()
        ..addAll(savedNotifications)
        ..sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );
      _captureError = null;
    });
  } catch (error) {
    if (mounted) {
      setState(() {
        _captureError = 'Unable to load saved notifications: $error';
      });
    }
  }
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
class _GroupedNotificationList extends StatelessWidget {
  const _GroupedNotificationList({
    required this.groups,
  });

  final Map<String, List<CapturedNotification>> groups;

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.toList();

    // The first notification in each group is the newest because
    // _notifications is already sorted newest → oldest.
    entries.sort(
      (a, b) => b.value.first.timestamp.compareTo(
        a.value.first.timestamp,
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final entry in entries) ...[
          _AppSectionHeader(
            appName: entry.key,
            notificationCount: entry.value.length,
          ),
          for (final notification in entry.value)
            _NotificationListItem(
              notification: notification,
            ),
        ],
      ],
    );
  }
}

class _AppSectionHeader extends StatelessWidget {
  const _AppSectionHeader({
    required this.appName,
    required this.notificationCount,
  });

  final String appName;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.apps, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Text(
            '$notificationCount',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: const CircleAvatar(
        child: Icon(Icons.notifications),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              notification.appName.isEmpty
                  ? notification.packageName
                  : notification.appName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatRelativeTime(notification.timestamp),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final localTimestamp = timestamp.toLocal();
    final difference = now.difference(localTimestamp);

    if (difference.isNegative || difference.inSeconds < 10) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${localTimestamp.day.toString().padLeft(2, '0')}/'
        '${localTimestamp.month.toString().padLeft(2, '0')}/'
        '${localTimestamp.year}';
  }
}