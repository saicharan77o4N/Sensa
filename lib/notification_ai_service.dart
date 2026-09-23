import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'captured_notification.dart';
import 'dart:math';
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
}