import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'captured_notification.dart';
import 'notification_ai_service.dart';
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
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String? _queryAnswer;
  bool _isFocusMode = false;
  DateTime? _focusEndsAt;
  Timer? _focusTimer;

  List<CapturedNotification> _searchResults = [];
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  StreamSubscription<CapturedNotification>? _notificationSubscription;

  bool _notificationAccessGranted = false;
  bool _checkingAccess = true;
  String? _captureError;

  @override
  void initState() {
    super.initState();
    NotificationAiService.instance.initialize();
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
      final notificationText = '${notification.title} ${notification.content}'
          .trim();

      final importanceScore = await NotificationAiService.instance
          .calculateImportanceScore(notificationText);

      final scoredNotification = CapturedNotification(
        id: notification.id,
        packageName: notification.packageName,
        appName: notification.appName,
        title: notification.title,
        content: notification.content,
        timestamp: notification.timestamp,
        importanceScore: importanceScore,
      );

      await _database.insertNotification(scoredNotification);

      if (!mounted) {
        return;
      }

      if (_isFocusMode &&
          (scoredNotification.importanceScore ?? 0.0) < 0.08) {
        debugPrint(
          'SENSA FOCUS | Quiet notification: '
          '${scoredNotification.appName} - '
          '${scoredNotification.title}',
        );

        setState(() {
          _notifications.add(scoredNotification);
          _notifications.sort(
            (a, b) => b.timestamp.compareTo(a.timestamp),
          );
          _captureError = null;
        });

        return;
      }

      setState(() {
        _notifications.add(scoredNotification);
        _notifications.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        );
        _captureError = null;
      });

      debugPrint(
        'SENSA SCORE | '
        '${scoredNotification.importanceScore} | '
        '${scoredNotification.title}',
      );
    } catch (error, stackTrace) {
      debugPrint('Notification AI scoring failed: $error');
      debugPrint('$stackTrace');

      if (mounted) {
        setState(() {
          _captureError = 'Unable to process notification: $error';
        });
      }
    }
  }

  Map<String, List<CapturedNotification>> _groupNotificationsByApp(
  List<CapturedNotification> notifications,
  ) {
    final groups = <String, List<CapturedNotification>>{};

    for (final notification in notifications) {
      final appName = notification.appName.isEmpty
          ? notification.packageName
          : notification.appName;

      groups.putIfAbsent(appName, () => []).add(notification);
    }

    return groups;
  }
  Future<void> _startListening() async {
  final available = await _speechToText.initialize(
    onStatus: (status) {
      debugPrint('SENSA SPEECH STATUS | $status');

      if (status == 'done' || status == 'notListening') {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    },
    onError: (error) {
      debugPrint('SENSA SPEECH ERROR | $error');

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    },
  );

  if (!available) {
    debugPrint('SENSA SPEECH | Speech recognition unavailable');
    return;
  }

  setState(() {
    _isListening = true;
  });

  await _speechToText.listen(
  onResult: (result) {
    final recognizedText = result.recognizedWords;

    debugPrint(
      'SENSA SPEECH RESULT | '
      '"$recognizedText" | '
      'final: ${result.finalResult}',
    );

    if (mounted) {
      setState(() {
        _searchController.text = recognizedText;
      });
    }

    if (result.finalResult && recognizedText.trim().isNotEmpty) {
    _handleVoiceCommand(recognizedText);

    if (!recognizedText.toLowerCase().contains('focus')) {
      _searchNotifications();
    }
}
  },
  listenOptions: SpeechListenOptions(
    partialResults: true,
    cancelOnError: false,
    listenMode: ListenMode.search,
  ),
);
}
Future<void> _stopListening() async {
  await _speechToText.stop();

  if (mounted) {
    setState(() {
      _isListening = false;
    });
  }
}
void _startFocusMode(Duration duration) {
  _focusTimer?.cancel();

  final endsAt = DateTime.now().add(duration);

  setState(() {
    _isFocusMode = true;
    _focusEndsAt = endsAt;
  });

  _focusTimer = Timer(
    duration,
    _stopFocusMode,
  );

  debugPrint(
    'SENSA FOCUS | Started for ${duration.inMinutes} minutes',
  );
}

void _stopFocusMode() {
  _focusTimer?.cancel();
  _focusTimer = null;

  if (!mounted) {
    return;
  }

  setState(() {
    _isFocusMode = false;
    _focusEndsAt = null;
  });

  debugPrint('SENSA FOCUS | Stopped');
}
void _handleVoiceCommand(String command) {
  final normalized = command.trim().toLowerCase();

  if (normalized.contains('focus')) {
    final minuteMatch = RegExp(
      r'(\d+)\s*(minute|minutes|min|mins)',
    ).firstMatch(normalized);

    final hourMatch = RegExp(
      r'(\d+)\s*(hour|hours|hr|hrs)',
    ).firstMatch(normalized);

    if (hourMatch != null) {
      final hours = int.parse(hourMatch.group(1)!);

      _startFocusMode(
        Duration(hours: hours),
      );

      return;
    }

    if (minuteMatch != null) {
      final minutes = int.parse(minuteMatch.group(1)!);

      _startFocusMode(
        Duration(minutes: minutes),
      );

      return;
    }

    debugPrint(
      'SENSA FOCUS | Could not understand duration',
    );
  }
}
Future<void> _speakAnswer(String answer) async {
  if (answer.trim().isEmpty) {
    return;
  }

  await _flutterTts.stop();

  await _flutterTts.setLanguage('en-US');
  await _flutterTts.setSpeechRate(0.5);
  await _flutterTts.setPitch(1.0);

  await _flutterTts.speak(answer);
}
List<CapturedNotification> get _visibleNotifications {
  if (!_isFocusMode) {
    return _notifications;
  }

  return _notifications.where((notification) {
    final score = notification.importanceScore ?? 0.0;

    return score >= 0.08;
  }).toList();
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensa'),
        actions: [
          IconButton(
            onPressed: _isFocusMode
                ? _stopFocusMode
                : () => _startFocusMode(const Duration(minutes: 30)),
            icon: Icon(
              _isFocusMode
                  ? Icons.notifications_active
                  : Icons.do_not_disturb_on_outlined,
            ),
            tooltip: _isFocusMode
                ? 'Turn off Focus Mode'
                : 'Focus for 30 minutes',
          ),
          IconButton(
            onPressed: _refreshNotificationAccess,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh notification access',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isFocusMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(),
              ),
              child: Text(
                _focusEndsAt == null
                    ? 'Focus Mode is active'
                    : 'Focus Mode active until '
                        '${_focusEndsAt!.hour.toString().padLeft(2, '0')}:'
                        '${_focusEndsAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          _AccessStatusCard(
            granted: _notificationAccessGranted,
            checking: _checkingAccess,
            onOpenSettings: _openNotificationAccessSettings,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                      ),
                      tooltip: _isListening
                          ? 'Stop listening'
                          : 'Voice search',
                    ),
                    IconButton(
                      onPressed: _searchNotifications,
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: 'Search',
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _searchNotifications(),
            ),
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
  child: _isSearching
      ? ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            if (_queryAnswer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _queryAnswer!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No matching notifications found'),
                ),
              )
            else
              for (final notification in _searchResults)
                _NotificationListItem(
                  notification: notification,
                ),
          ],
        )
      : (_visibleNotifications.isEmpty
          ? const _EmptyNotificationList()
          : _GroupedNotificationList(
              groups: _groupNotificationsByApp(
                _visibleNotifications,
              ),
            )),
            ),
        ],
      ),
    );
  }

  Future<void> _testMiniLm() async {
    try {
      final embedding = await NotificationAiService.instance.getEmbedding(
        'Your OTP is 4821',
      );

      debugPrint('MiniLM test embedding length: ${embedding.length}');

      debugPrint('MiniLM first 5 values: ${embedding.take(5).toList()}');
    } catch (error, stackTrace) {
      debugPrint('MiniLM test failed: $error');
      debugPrint('$stackTrace');
    }
  }
  
  Future<void> _testImportanceRanking() async {
    final testNotifications = [
      'Your OTP for login is 4821. Do not share this code.',
      'Your bank account was debited ₹2,500 for a transaction.',
      'Congratulations! You won a special discount. Shop now!',
      'A new entertaining video is waiting for you.',
    ];

    for (final notification in testNotifications) {
      try {
        final score = await NotificationAiService.instance
            .calculateImportanceScore(notification);

        debugPrint('IMPORTANCE TEST | $score | $notification');
      } catch (error, stackTrace) {
        debugPrint('Importance test failed: $error');
        debugPrint('$stackTrace');
      }
    }
  }
  

  Future<void> _loadSavedNotifications() async {
    try {
      final savedNotifications = await _database.getNotifications();
      debugPrint(
        'SENSA DATABASE | Loaded ${savedNotifications.length} notifications',
      );

      for (final notification in savedNotifications) {
        debugPrint(
          'SENSA DATABASE | '
          '${notification.appName} | '
          '${notification.title} | '
          'score=${notification.importanceScore}',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications
          ..clear()
          ..addAll(savedNotifications)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
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

  Future<void> _searchNotifications() async {
  final query = _searchController.text.trim();

  debugPrint('SENSA QUERY START | query: "$query"');

  if (query.isEmpty) {
  setState(() {
    _isSearching = false;
    _queryAnswer = null;
    _searchResults = [];
  });
  return;
}

  setState(() {
    _isSearching = true;
  });

  try {
    final result = await NotificationAiService.instance.answerQuery(
      query,
      _notifications,
    );

    if (!mounted) {
      return;
    }

    setState(() {
    _queryAnswer = result.answer;
      _searchResults = result.notifications;
    });

await _speakAnswer(result.answer);

    debugPrint(
      'SENSA QUERY ANSWER | '
      '"$query" | '
      '${result.answer} | '
      'matches: ${result.notifications.length}',
    );
  } catch (error, stackTrace) {
    debugPrint('Sensa query failed: $error');
    debugPrint('$stackTrace');

    if (mounted) {
      setState(() {
        _captureError = 'Unable to process query: $error';
        _searchResults = [];
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
  const _GroupedNotificationList({required this.groups});

  final Map<String, List<CapturedNotification>> groups;

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.toList();

    // The first notification in each group is the newest because
    // _notifications is already sorted newest → oldest.
    entries.sort(
      (a, b) => b.value.first.timestamp.compareTo(a.value.first.timestamp),
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
            _NotificationListItem(notification: notification),
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
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
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
  String _importanceLabel() {
    final score = notification.importanceScore;

    if (score == null) {
      return 'UNRANKED';
    }

    if (score >= 0.08) {
      return 'HIGH';
    }

    if (score >= 0.02) {
      return 'MEDIUM';
    }

    return 'LOW';
  }

  @override
  Widget build(BuildContext context) {
    final title = notification.title.isEmpty ? 'No title' : notification.title;
    final content = notification.content.isEmpty
        ? 'No content'
        : notification.content;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(child: Icon(Icons.notifications)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              notification.appName.isEmpty
                  ? notification.packageName
                  : notification.appName,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _importanceLabel(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
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
