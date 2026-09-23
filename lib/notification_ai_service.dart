import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'captured_notification.dart';
import 'dart:math';
enum NotificationQueryIntent {
  search,
  count,
  today,
  important,
}
class NotificationQueryResult {
  const NotificationQueryResult({
    required this.intent,
    required this.answer,
    required this.notifications,
  });

  final NotificationQueryIntent intent;
  final String answer;
  final List<CapturedNotification> notifications;
}
class NotificationQueryContext {
  const NotificationQueryContext({
    required this.intent,
    required this.topic,
    required this.isToday,
  });

  final NotificationQueryIntent intent;
  final String? topic;
  final bool isToday;
}
class NotificationAiService {
  NotificationAiService._();

  static final NotificationAiService instance =
      NotificationAiService._();

  final OnnxRuntime _onnxRuntime = OnnxRuntime();

  OrtSession? _onnxSession;
  WordPieceTokenizer? _tokenizer;
  Future<void>? _initializationFuture;
    final List<String> _importantConcepts = [
    'urgent important notification',
    'work or college notification',
    'financial transaction or bank alert',
    'security alert or verification code',
    'important personal message',
  ];

  final List<String> _distractionConcepts = [
    'advertisement promotion marketing',
    'social media entertainment',
    'spam or unwanted notification',
  ];

  List<List<double>>? _importantConceptEmbeddings;
  List<List<double>>? _distractionEmbeddings;

  Future<void> initialize() {
  if (_onnxSession != null && _tokenizer != null) {
    return Future.value();
  }

  return _initializationFuture ??= _initialize();
}

Future<void> _initialize() async {
  try {
    debugPrint('Loading Sensa MiniLM tokenizer...');

    final tokenizerJson = await rootBundle.loadString(
      'model/minilm/tokenizer.json',
    );

    _tokenizer =
        WordPieceTokenizer.fromTokenizerJsonString(
      tokenizerJson,
    );

    debugPrint(
      'Sensa MiniLM tokenizer loaded successfully!',
    );

    debugPrint('Loading Sensa MiniLM ONNX model...');

    _onnxSession =
        await _onnxRuntime.createSessionFromAsset(
      'model/minilm/minilm_embedding.onnx',
    );

    debugPrint(
      'Sensa MiniLM ONNX model loaded successfully!',
    );

    debugPrint(
      'Input names: ${_onnxSession!.inputNames}',
    );

    debugPrint(
      'Output names: ${_onnxSession!.outputNames}',
    );
  } catch (error) {
    _initializationFuture = null;
    rethrow;
  }
}
  Future<void> _initializeConceptEmbeddings() async {
    if (_importantConceptEmbeddings != null &&
        _distractionEmbeddings != null) {
      return;
    }

    _importantConceptEmbeddings = [];

    for (final concept in _importantConcepts) {
      _importantConceptEmbeddings!.add(
        await getEmbedding(concept),
      );
    }

    _distractionEmbeddings = [];

    for (final concept in _distractionConcepts) {
      _distractionEmbeddings!.add(
        await getEmbedding(concept),
      );
    }

    debugPrint(
      'Sensa importance concepts initialized.',
    );
  }
  Future<List<double>> getEmbedding(
    String text,
  ) async {
    if (_tokenizer == null || _onnxSession == null) {
      await initialize();
    }

    final encoding = _tokenizer!.encode(text);

    final inputIds = Int64List.fromList(
      encoding.ids,
    );

    final attentionMask = Int64List.fromList(
      encoding.attentionMask,
    );

    final inputIdsValue = await OrtValue.fromList(
      inputIds,
      [1, inputIds.length],
    );

    final attentionMaskValue =
        await OrtValue.fromList(
      attentionMask,
      [1, attentionMask.length],
    );

    final outputs = await _onnxSession!.run({
      'input_ids': inputIdsValue,
      'attention_mask': attentionMaskValue,
    });

    final embedding = await outputs[
      'sentence_embedding'
    ]!.asFlattenedList();

    await inputIdsValue.dispose();
    await attentionMaskValue.dispose();

    return embedding.cast<double>();
  }
    Future<double> calculateImportanceScore(String text) async {
    await _initializeConceptEmbeddings();

    final notificationEmbedding =
        await getEmbedding(text);

    double importantScore = 0;

    for (final conceptEmbedding
        in _importantConceptEmbeddings!) {
      importantScore += cosineSimilarity(
        notificationEmbedding,
        conceptEmbedding,
      );
    }

    double distractionScore = 0;

    for (final conceptEmbedding
        in _distractionEmbeddings!) {
      distractionScore += cosineSimilarity(
        notificationEmbedding,
        conceptEmbedding,
      );
    }

    importantScore /=
        _importantConceptEmbeddings!.length;

    distractionScore /=
        _distractionEmbeddings!.length;

    return importantScore - distractionScore;
  }
    Future<List<MapEntry<CapturedNotification, double>>>
        searchNotifications(
    String query,
    List<CapturedNotification> notifications,
    ) async {
    final queryEmbedding = await getEmbedding(query);

    final results =
        <MapEntry<CapturedNotification, double>>[];

    for (final notification in notifications) {
        final notificationText =
            '${notification.title} ${notification.content}'.trim();

        if (notificationText.isEmpty) {
        continue;
        }

        final notificationEmbedding =
            await getEmbedding(notificationText);

        final similarity = cosineSimilarity(
        queryEmbedding,
        notificationEmbedding,
        );

        results.add(
        MapEntry(
            notification,
            similarity,
        ),
        );
    }

    results.sort(
        (a, b) => b.value.compareTo(a.value),
    );

    return results;
    }
double cosineSimilarity(
  List<double> a,
  List<double> b,
) {
  if (a.length != b.length) {
    throw ArgumentError(
      'Embedding lengths must match.',
    );
  }

  double dotProduct = 0;
  double magnitudeA = 0;
  double magnitudeB = 0;

  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    magnitudeA += a[i] * a[i];
    magnitudeB += b[i] * b[i];
  }

  if (magnitudeA == 0 || magnitudeB == 0) {
    return 0;
  }

  return dotProduct /
      (sqrt(magnitudeA) * sqrt(magnitudeB));
}
String understandQuery(String query) {
  final normalized = query.trim().toLowerCase();

  if (normalized.isEmpty) {
    return '';
  }

  const prefixes = [
    'show me',
    'show',
    'find me',
    'find',
    'search for',
    'search',
    'give me',
    'get me',
    'get',
    'what are',
    'what is',
  ];

  for (final prefix in prefixes) {
    if (normalized.startsWith('$prefix ')) {
      return normalized.substring(prefix.length).trim();
    }
  }

  return normalized;
}
NotificationQueryIntent detectQueryIntent(String query) {
  final normalized = query.trim().toLowerCase();

  if (normalized.isEmpty) {
    return NotificationQueryIntent.search;
  }

  if (normalized.contains('how many') ||
      normalized.contains('count') ||
      normalized.contains('number of')) {
    return NotificationQueryIntent.count;
  }

  if (normalized.contains('today') ||
      normalized.contains('this morning') ||
      normalized.contains('this afternoon') ||
      normalized.contains('tonight')) {
    return NotificationQueryIntent.today;
  }

  if (normalized.contains('important') ||
      normalized.contains('urgent') ||
      normalized.contains('priority')) {
    return NotificationQueryIntent.important;
  }

  return NotificationQueryIntent.search;
}
NotificationQueryContext extractQueryContext(String query) {
  final normalized = query.trim().toLowerCase();
  final intent = detectQueryIntent(normalized);

  final isToday =
      normalized.contains('today') ||
      normalized.contains('this morning') ||
      normalized.contains('this afternoon') ||
      normalized.contains('tonight');

  String? topic;

  var cleaned = normalized;

  const timePhrases = [
    'today',
    'this morning',
    'this afternoon',
    'tonight',
  ];

  for (final phrase in timePhrases) {
    cleaned = cleaned.replaceAll(phrase, ' ');
  }

  const questionPhrases = [
  'did i receive any',
  'did i receive',
  'have i received any',
  'have i received',
  'what notifications did i receive',
  'what notifications do i have',
  'what notifications did i get',
  'what notifications do i get',
  'show me',
  'show',
  'find me',
  'find',
  'search for',
  'search',
  'give me',
  'get me',
  'get',
];

  for (final phrase in questionPhrases) {
    cleaned = cleaned.replaceAll(phrase, ' ');
  }
  cleaned = cleaned
    .replaceAll('what', ' ')
    .replaceAll('did i', ' ')
    .replaceAll('do i', ' ')
    .replaceAll('have i', ' ')
    .replaceAll('receive', ' ')
    .replaceAll('received', ' ')
    .replaceAll('get', ' ');

  cleaned = cleaned
    .replaceAll('notifications', ' ')
    .replaceAll('notification', ' ')
    .replaceAll('any', ' ')
    .replaceAll('the', ' ')
    .replaceAll('?', ' ')
    .replaceAll('.', ' ')
    .trim();
    if (intent == NotificationQueryIntent.count ||
    intent == NotificationQueryIntent.important) {
  cleaned = '';
}

  if (cleaned.isNotEmpty) {
    topic = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  return NotificationQueryContext(
    intent: intent,
    topic: topic,
    isToday: isToday,
  );
}
Future<NotificationQueryResult> answerQuery(
  String query,
  List<CapturedNotification> notifications,
) async {
  final intent = detectQueryIntent(query);

  switch (intent) {
    case NotificationQueryIntent.count:
      return NotificationQueryResult(
        intent: intent,
        answer: 'You have ${notifications.length} notifications.',
        notifications: notifications,
      );

    case NotificationQueryIntent.today:
        final context = extractQueryContext(query);
        final now = DateTime.now();

        var todayNotifications = notifications.where((notification) {
            final timestamp = notification.timestamp.toLocal();

            return timestamp.year == now.year &&
                timestamp.month == now.month &&
                timestamp.day == now.day;
        }).toList();

        if (context.topic != null) {
            final topicResults = await searchNotifications(
            context.topic!,
            todayNotifications,
            );

    const minimumSimilarity = 0.35;

    todayNotifications = topicResults
        .where((entry) => entry.value >= minimumSimilarity)
        .map((entry) => entry.key)
        .toList();
  }

    final count = todayNotifications.length;
    final notificationWord = count == 1 ? 'notification' : 'notifications';
    final answer = count == 0
    ? context.topic == null
        ? 'You have no notifications from today.'
        : 'You have no ${context.topic} notifications from today.'
    : context.topic == null
        ? 'You have $count $notificationWord from today.'
        : 'You have $count ${context.topic} $notificationWord from today.';

  return NotificationQueryResult(
    intent: intent,
    answer: answer,
    notifications: todayNotifications,
  );

    case NotificationQueryIntent.important:
      final importantNotifications = notifications.where((notification) {
        final score = notification.importanceScore;
        return score != null && score >= 0.08;
      }).toList();

      return NotificationQueryResult(
        intent: intent,
        answer: importantNotifications.isEmpty
            ? 'You have no high-priority notifications.'
            : 'You have ${importantNotifications.length} high-priority notifications.',
        notifications: importantNotifications,
      );

    case NotificationQueryIntent.search:
      final understoodQuery = understandQuery(query);

      final results = await searchNotifications(
        understoodQuery,
        notifications,
      );

      final matchingNotifications =
          results.map((entry) => entry.key).toList();

      return NotificationQueryResult(
        intent: intent,
        answer: matchingNotifications.isEmpty
            ? 'I could not find matching notifications.'
            : 'I found ${matchingNotifications.length} matching notifications.',
        notifications: matchingNotifications,
      );
  }
}
}