import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class NotificationAiService {
  NotificationAiService._();

  static final NotificationAiService instance =
      NotificationAiService._();

  final OnnxRuntime _onnxRuntime = OnnxRuntime();

  OrtSession? _onnxSession;
  WordPieceTokenizer? _tokenizer;
  Future<void>? _initializationFuture;
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
}