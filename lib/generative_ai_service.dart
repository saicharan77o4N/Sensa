import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
class GenerativeAiService {
  GenerativeAiService._();

  static final GenerativeAiService instance = GenerativeAiService._();

  static const String _baseUrl = 'http://10.0.2.2:11434';
  static const String _model = 'qwen3:1.7b';
  Future<String> summarizeNotification({
    required String title,
    required String content,
  }) async {
    final facts = _extractFacts(content);

    final systemPrompt = '''
You are Sensa, an AI assistant that summarizes Android notification messages.

Your priority is ACCURACY.

Preserve:
- the original meaning
- important facts
- responsibilities
- requests
- questions
- dates
- times
- deadlines
- actions
- reasons or causes
- numbers and amounts
- links when important

IMPORTANT ROLE RULES:

The SENDER is the person who wrote the message.

Words such as:
"I", "me", "my", "I'll", "I will", "I've", "I need"
refer to the SENDER.

Words such as:
"you", "your", "you'll", "you will", "can you", "could you", "please"
refer to the RECIPIENT.

Words such as:
"we", "us", "our", "let's", "we can", "we should"
refer to SHARED responsibility between sender and recipient.

NEVER transfer an action from one person to another.

Do not turn a sender action into a recipient action.
Do not turn a recipient request into a sender action.
Do not turn a shared action into a sender-only or recipient-only action.

The following facts were extracted deterministically from the original message.

FACTS:
$facts

Treat these facts as authoritative.

Your job is only to express these facts naturally and concisely.

Example:

Message:
"Can you finish the API docs by tomorrow? I'll handle the frontend deck and we can sync at 4pm."

Facts:
Recipient: finish the API docs by tomorrow.
Sender: handle the frontend deck.
Shared: sync at 4 PM.

Correct summary:
"The recipient needs to finish the API documentation by tomorrow; the sender will handle the frontend deck, and both will sync at 4 PM."

Example:

Message:
"I didn't finish my slides yet. I'll share the template on Drive. We should include the bug-fix stats. Let's join the meeting 5 minutes early."

Facts:
Sender: has not finished slides.
Sender: will share template on Drive.
Shared: include bug-fix stats.
Shared: join the meeting 5 minutes early.

Correct summary:
"The sender hasn't finished their slides and will share the template on Drive; both should include the bug-fix stats and join the meeting 5 minutes early."

Important:
- Do not invent information.
- Do not add facts that are not present.
- Do not remove important facts.
- Preserve important reasons or causes.
- Preserve the distinction between sender, recipient, and shared actions.
- Do not change a statement into a request or instruction.
- Do not claim that someone completed an action unless the message says so.

Return ONLY the final summary.
Do not explain your reasoning.
''';

    final userContent = '''
Sender/title:
$title

Original message:
$content
''';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/chat'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userContent,
          },
        ],
        'stream': false,
        'options': {
          'temperature': 0.0,
          'repeat_penalty': 1.1,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Generative AI request failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final message =
        data['message'] as Map<String, dynamic>?;

    final summary =
        message?['content'] as String?;

    if (summary == null || summary.trim().isEmpty) {
      throw Exception(
        'Generative AI returned an empty response.',
      );
    }

    final cleanedSummary = summary.trim();

    if (_containsUnsupportedFinancialClaim(
      cleanedSummary,
      content,
    )) {
      throw Exception(
        'Generative AI produced an unsupported financial claim.',
      );
    }

        final validation = _validateSummary(
        originalContent: content,
        summary: cleanedSummary,
      );

      if (!validation.isValid) {
      debugPrint(
        'SENSA GEN AI | Validation failed: ${validation.reason}',
      );

      final fallback = _generateFallbackSummary(content);

      debugPrint(
        'SENSA GEN AI | Trying validated fallback: $fallback',
      );

      final fallbackValidation = _validateSummary(
        originalContent: content,
        summary: fallback,
      );

      if (fallbackValidation.isValid) {
        debugPrint(
          'SENSA GEN AI | Fallback validation passed',
        );

        return fallback;
      }

      debugPrint(
        'SENSA GEN AI | Fallback validation failed: '
        '${fallbackValidation.reason}',
      );

      debugPrint(
        'SENSA GEN AI | Returning original notification as safe fallback',
      );

      return content.trim();
    }

      debugPrint(
        'SENSA GEN AI | Validation passed',
      );

      return cleanedSummary;
  }

  String debugExtractFacts(String content) {
  return _extractFacts(content);
}
  String debugValidateSummary({
    required String originalContent,
    required String summary,
  }) {
    final validation = _validateSummary(
      originalContent: originalContent,
      summary: summary,
    );

    return validation.isValid
        ? 'PASS'
        : 'FAIL: ${validation.reason}';
  }
  String _extractFacts(String content) {
    final sentences = _splitSentences(content);

    final senderActions = <String>[];
    final recipientActions = <String>[];
    final sharedActions = <String>[];
    final questions = <String>[];

    for (final sentence in sentences) {
      final trimmed = sentence.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      final lower = trimmed.toLowerCase();

      // Shared responsibility must be checked first.
      if (_containsAny(lower, [
        'we ',
        'we\'ll',
        'we will',
        'we should',
        'we can',
        'let\'s',
        'lets ',
        'our ',
        'us ',
      ])) {
        sharedActions.add(trimmed);
        continue;
      }

      // Recipient responsibility / request.
      if (_containsAny(
      lower,
      [
        'can you',
        'could you',
        'would you',
        'will you',
        'please',
        'you should',
        'you need to',
        'you have to',
        'you\'ll',
        'you will',
        'your ',
      ],
    )) {
      // A direct question such as:
      // "Can you send me the report?"
      // is primarily a question/request, not a confirmed
      // recipient action.
      if (_looksLikeQuestion(sentence)) {
        continue;
      }

      recipientActions.add(sentence);
      continue;
    }

      // Sender responsibility / statement.
      if (_containsAny(lower, [
        'i ',
        'i\'ll ',
        'i will ',
        'i\'m ',
        'i am ',
        'i\'ve ',
        'i have ',
        'i need ',
        'my ',
      ])) {
        senderActions.add(trimmed);

        if (_looksLikeQuestion(trimmed)) {
          questions.add(trimmed);
        }

        continue;
      }

      // Preserve standalone questions even when they do not
      // contain an obvious role marker.
      if (_looksLikeQuestion(trimmed)) {
        questions.add(trimmed);
      }
    }

    final buffer = StringBuffer();

    if (senderActions.isNotEmpty) {
      buffer.writeln(
        'Sender statements/actions:',
      );

      for (final action in senderActions) {
        buffer.writeln('- $action');
      }
    }

    if (recipientActions.isNotEmpty) {
      buffer.writeln(
        'Recipient requests/actions:',
      );

      for (final action in recipientActions) {
        buffer.writeln('- $action');
      }
    }

    if (sharedActions.isNotEmpty) {
      buffer.writeln(
        'Shared actions:',
      );

      for (final action in sharedActions) {
        buffer.writeln('- $action');
      }
    }

    if (questions.isNotEmpty) {
      buffer.writeln(
        'Questions:',
      );

      for (final question in questions) {
        buffer.writeln('- $question');
      }
    }

    final exactFacts = _extractExactFacts(content);

    if (exactFacts.isNotEmpty) {
      buffer.writeln(
        'Important exact facts:',
      );

      for (final fact in exactFacts) {
        buffer.writeln('- $fact');
      }
    }

    if (buffer.isEmpty) {
      return 'No deterministic role facts were extracted. Preserve the original message accurately.';
    }

    return buffer.toString().trim();
  }

  List<String> _splitSentences(String content) {
    return content
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();
  }

  List<String> _extractExactFacts(String content) {
    final facts = <String>[];

    final times = RegExp(
      r'\b(?:at|by|before|after|around|until)\s+'
      r'\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b',
      caseSensitive: false,
    ).allMatches(content);

    for (final match in times) {
      facts.add(match.group(0)!);
    }

    final dates = RegExp(
      r'\b(?:today|tomorrow|tonight|yesterday|'
      r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'this week|next week|this month|next month)\b',
      caseSensitive: false,
    ).allMatches(content);

    for (final match in dates) {
      facts.add(match.group(0)!);
    }

    final urls = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).allMatches(content);

    for (final match in urls) {
      facts.add(match.group(0)!);
    }

    final numbers = RegExp(
      r'\b\d+(?:\.\d+)?%?\b',
    ).allMatches(content);

    for (final match in numbers) {
      final value = match.group(0)!;

      if (!facts.contains(value)) {
        facts.add(value);
      }
    }

    return facts;
  }

      _SummaryValidation _validateSummary({
    required String originalContent,
    required String summary,
  }) {
    final summaryLower = summary.toLowerCase();

    // Extract the same deterministic role facts that were supplied
    // to the LLM. The validator treats these as authoritative.
    final facts = _extractRoleFacts(originalContent);

    // Validate every recipient action.
    for (final action in facts.recipientActions) {
      if (!_summaryAssignsActionToRole(
        summary: summaryLower,
        action: action,
        requiredRole: _SummaryRole.recipient,
      )) {
        return _SummaryValidation(
          isValid: false,
          reason:
              'Recipient responsibility changed or was lost: "$action"',
        );
      }
    }

    // Validate every sender action.
    for (final action in facts.senderActions) {
      if (!_summaryAssignsActionToRole(
        summary: summaryLower,
        action: action,
        requiredRole: _SummaryRole.sender,
      )) {
        return _SummaryValidation(
          isValid: false,
          reason:
              'Sender responsibility changed or was lost: "$action"',
        );
      }
    }

    // Validate every shared action.
    for (final action in facts.sharedActions) {
      if (!_summaryAssignsActionToRole(
        summary: summaryLower,
        action: action,
        requiredRole: _SummaryRole.shared,
      )) {
        return _SummaryValidation(
          isValid: false,
          reason:
              'Shared responsibility changed or was lost: "$action"',
        );
      }
    }
        // Named-person responsibilities must stay attached
    // to the same person.
    final namedPersonProblems = _validateNamedPersonFacts(
      originalContent: originalContent,
      summary: summary,
    );

    if (namedPersonProblems.isNotEmpty) {
      return _SummaryValidation(
        isValid: false,
        reason: namedPersonProblems.first,
      );
    }

    // Important times must survive.
    final originalTimes = _extractTimes(originalContent);

    for (final time in originalTimes) {
      if (!_summaryContainsEquivalentTime(
        summary,
        time,
      )) {
        return _SummaryValidation(
          isValid: false,
          reason: 'Important time "$time" was lost.',
        );
      }
    }

    // Important dates/day names must survive.
    final originalDates = _extractDates(originalContent);

    for (final date in originalDates) {
      if (!summaryLower.contains(date.toLowerCase())) {
        return _SummaryValidation(
          isValid: false,
          reason: 'Important date "$date" was lost.',
        );
      }
    }
    // Important numbers must survive unchanged.
    final originalNumbers = _extractNumbers(originalContent);

    for (final number in originalNumbers) {
      if (!_summaryContainsEquivalentNumber(summary, number)) {
        return _SummaryValidation(
          isValid: false,
          reason: 'Important number "$number" was lost or changed.',
        );
      }
    }

    // Questions should not silently disappear.
    final originalQuestions = _splitSentences(originalContent)
        .where(_looksLikeQuestion)
        .toList();

    if (originalQuestions.isNotEmpty) {
      final hasQuestionMeaning =
          summary.contains('?') ||
          summaryLower.contains('asked') ||
          summaryLower.contains('whether') ||
          summaryLower.contains('question');

      if (!hasQuestionMeaning) {
        return const _SummaryValidation(
          isValid: false,
          reason: 'Important question may have been lost.',
        );
      }
    }

    return const _SummaryValidation(
      isValid: true,
      reason: 'Summary preserved required information.',
    );
  }

    _RoleFacts _extractRoleFacts(String content) {
    final sentences = _splitSentences(content);

    final senderActions = <String>[];
    final recipientActions = <String>[];
    final sharedActions = <String>[];
    final questions = <String>[];

    for (final sentence in sentences) {
      final trimmed = sentence.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      final lower = trimmed.toLowerCase();

      // Questions must be preserved as questions.
      // They are not confirmed responsibilities.
      if (_looksLikeQuestion(trimmed)) {
        questions.add(trimmed);
        continue;
      }

      // Shared responsibility must be checked first.
      if (_containsAny(lower, [
        'we ',
        'we\'ll',
        'we will',
        'we should',
        'we can',
        'let\'s',
        'lets ',
        'our ',
        'us ',
      ])) {
        sharedActions.add(trimmed);
        continue;
      }

      // Recipient responsibility / direct request.
      if (_containsAny(lower, [
        'can you ',
        'could you ',
        'would you ',
        'will you ',
        'please ',
        'you should ',
        'you need to ',
        'you have to ',
        'you\'ll ',
        'you will ',
        'your ',
      ])) {
        recipientActions.add(trimmed);
        continue;
      }

      // Sender responsibility / statement.
      if (_containsAny(lower, [
        'i\'ll ',
        'i will ',
        'i need to ',
        'i have to ',
        'i should ',
        'i can ',
        'i\'m going to ',
        'i am going to ',
        'my ',
      ])) {
        senderActions.add(trimmed);
      }
    }

    return _RoleFacts(
      senderActions: senderActions,
      recipientActions: recipientActions,
      sharedActions: sharedActions,
      questions: questions,
    );
  }

  bool _summaryAssignsActionToRole({
    required String summary,
    required String action,
    required _SummaryRole requiredRole,
  }) {
    final actionWords = _extractActionWords(action);

    if (actionWords.isEmpty) {
      return true;
    }

    // The summary must contain enough of the original action's
    // meaningful words to establish that the same action survived.
    final matchingWords = actionWords
        .where(summary.contains)
        .length;

    final minimumMatches =
        actionWords.length <= 2 ? actionWords.length : 2;

    if (matchingWords < minimumMatches) {
      return false;
    }

    final hasSenderMarker =
        summary.contains('sender') ||
        summary.contains('i will') ||
        summary.contains("i'll") ||
        summary.contains('i need to') ||
        summary.contains('the speaker');

    final hasRecipientMarker =
        summary.contains('recipient') ||
        summary.contains('you need to') ||
        summary.contains('you should') ||
        summary.contains('you have to') ||
        summary.contains('the other person');

    final hasSharedMarker =
        summary.contains('both') ||
        summary.contains('shared') ||
        summary.contains('together') ||
        summary.contains('they will') ||
        summary.contains('they should') ||
        summary.contains('we will') ||
        summary.contains('we should');

    switch (requiredRole) {
      case _SummaryRole.sender:
        // Explicit recipient wording for the same action is a
        // responsibility reversal.
        if (hasRecipientMarker && !hasSenderMarker) {
          return false;
        }

        return hasSenderMarker;

      case _SummaryRole.recipient:
        // Explicit sender wording for the same action is a
        // responsibility reversal.
        if (hasSenderMarker && !hasRecipientMarker) {
          return false;
        }

        return hasRecipientMarker;

      case _SummaryRole.shared:
        // A shared action must not become sender-only or
        // recipient-only.
        if (!hasSharedMarker) {
          return false;
        }

        return true;
    }
  }

  List<String> _extractActionWords(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .toList();

    const ignoredWords = {
      'that',
      'this',
      'with',
      'from',
      'have',
      'will',
      'would',
      'could',
      'should',
      'your',
      'you',
      'they',
      'them',
      'then',
      'were',
      'been',
      'what',
      'when',
      'where',
      'which',
      'about',
      'because',
      'actually',
      'still',
      'just',
      'very',
      'into',
      'their',
      'there',
      'same',
      'more',
      'only',
      'than',
      'also',
    };

    return words
        .where((word) => !ignoredWords.contains(word))
        .toList();
  }

  List<String> _extractTimes(String text) {
    final matches = RegExp(
      r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b',
      caseSensitive: false,
    ).allMatches(text);

    return matches
        .map((match) => match.group(0)!.toLowerCase())
        .toList();
  }

  List<String> _extractDates(String text) {
    final matches = RegExp(
      r'\b(?:today|tomorrow|tonight|yesterday|'
      r'monday|tuesday|wednesday|thursday|friday|'
      r'saturday|sunday|this week|next week|'
      r'this month|next month)\b',
      caseSensitive: false,
    ).allMatches(text);

    return matches
        .map((match) => match.group(0)!.toLowerCase())
        .toList();
  }

  bool _summaryContainsEquivalentTime(
    String summary,
    String originalTime,
  ) {
    final summaryTimes = _extractTimes(summary);

    if (summaryTimes.contains(originalTime.toLowerCase())) {
      return true;
    }

    // Allow "4pm" and "4 PM" style formatting differences.
    final normalizedOriginal = originalTime
        .toLowerCase()
        .replaceAll(' ', '');

    return summaryTimes.any(
      (time) => time.replaceAll(' ', '') == normalizedOriginal,
    );
  }

  String _generateFallbackSummary(String content) {
    final sentences = _splitSentences(content);

    if (sentences.isEmpty) {
      return content.trim();
    }

    final importantSentences = <String>[];

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();

      final isAction = _containsAny(lower, [
        'can you ',
        'could you ',
        'please ',
        'you should ',
        'you need to ',
        'you have to ',
        'i\'ll ',
        'i will ',
        'i need to ',
        'we should ',
        'we can ',
        'let\'s ',
      ]);

      final containsImportantFact =
          _extractTimes(sentence).isNotEmpty ||
          _extractDates(sentence).isNotEmpty ||
          sentence.contains('?');

      if (isAction || containsImportantFact) {
        importantSentences.add(sentence);
      }
    }

    if (importantSentences.isEmpty) {
      return sentences.join(' ');
    }

    return importantSentences.join(' ');
  }

List<String> _extractNumbers(String content) {
  final numbers = RegExp(
    r'\b\d+(?:\.\d+)?%?\b',
  ).allMatches(content);

  return numbers
      .map((match) => match.group(0)!)
      .toSet()
      .toList();
}

bool _summaryContainsEquivalentNumber(
  String summary,
  String originalNumber,
) {
  final summaryNumbers = _extractNumbers(summary);

  return summaryNumbers.contains(originalNumber);
}
  List<String> _validateNamedPersonFacts({
    required String originalContent,
    required String summary,
  }) {
    final problems = <String>[];

    final sentences = _splitSentences(originalContent);

    for (final sentence in sentences) {
      final fact = _extractNamedPersonAction(sentence);

      if (fact == null) {
        continue;
      }

      final person = fact.person;
      final action = fact.action;

      final summarySegment = _findBestActionSegment(
        action: action,
        summary: summary,
      );

      if (summarySegment == null) {
        continue;
      }

      final segmentLower = summarySegment.toLowerCase();

      // The original person must still be attached to
      // the same action.
      if (!segmentLower.contains(person.toLowerCase())) {
        final otherPerson = _findOtherNamedPerson(
          segment: summarySegment,
          originalPerson: person,
        );

        if (otherPerson != null) {
          problems.add(
            'Named person responsibility changed: '
            '$person -> $otherPerson for action: $action',
          );
        }
      }
    }

    return problems;
  }

  _NamedPersonAction? _extractNamedPersonAction(
    String sentence,
  ) {
    final normalized = sentence
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    /*
     * Match patterns such as:
     *
     * Priya will prepare the slides.
     * Rahul can handle the backend.
     * Priya should send the report.
     * Rahul needs to review the code.
     * Priya must finish the presentation.
     */

    final match = RegExp(
      r'^([A-Z][a-zA-Z]{2,})\s+'
      r'(?:will|can|should|must|needs to|need to|'
      r'is going to|has to|have to)\s+'
      r'(.+)$',
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final person = match.group(1)?.trim();

    final action = match.group(2)
        ?.trim()
        .replaceFirst(RegExp(r'[.!?]+$'), '');

    if (person == null ||
        person.isEmpty ||
        action == null ||
        action.isEmpty) {
      return null;
    }

    return _NamedPersonAction(
      person: person,
      action: action,
    );
  }

  String? _findBestActionSegment({
    required String action,
    required String summary,
  }) {
    final summarySentences = _splitSentences(summary);

    if (summarySentences.isEmpty) {
      return null;
    }

    final actionWords = action
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 3)
        .toSet();

    String? bestSegment;
    var bestScore = 0;

    for (final sentence in summarySentences) {
      final sentenceWords = sentence
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .map(
            (word) => word.replaceAll(
              RegExp(r'[^a-z0-9_-]'),
              '',
            ),
          )
          .where((word) => word.length >= 3)
          .toSet();

      final score = actionWords.intersection(
        sentenceWords,
      ).length;

      if (score > bestScore) {
        bestScore = score;
        bestSegment = sentence;
      }
    }

    return bestScore >= 1 ? bestSegment : null;
  }

  String? _findOtherNamedPerson({
    required String segment,
    required String originalPerson,
  }) {
    final matches = RegExp(
      r'\b[A-Z][a-zA-Z]{2,}\b',
    ).allMatches(segment);

    for (final match in matches) {
      final candidate = match.group(0)!;

      if (candidate.toLowerCase() ==
          originalPerson.toLowerCase()) {
        continue;
      }

      const ignored = {
        'The',
        'Sender',
        'Recipient',
        'Both',
        'Google',
        'Drive',
        'Meet',
      };

      if (ignored.contains(candidate)) {
        continue;
      }

      return candidate;
    }

    return null;
  }
  bool _containsAny(
    String text,
    List<String> patterns,
  ) {
    return patterns.any(text.contains);
  }

  bool _looksLikeQuestion(String text) {
    return text.trim().endsWith('?');
  }

  bool _containsUnsupportedFinancialClaim(
    String summary,
    String content,
  ) {
    final summaryLower = summary.toLowerCase();
    final contentLower = content.toLowerCase();

    const financialWords = [
      'price',
      'cost',
      'paid',
      'payment',
      'amount',
      'rupees',
      'rs.',
      'inr',
      '₹',
      '\$',
      'usd',
      'dollar',
    ];

    final summaryHasFinancialClaim = financialWords.any(
      summaryLower.contains,
    );

    if (!summaryHasFinancialClaim) {
      return false;
    }

    final contentHasFinancialContext = financialWords.any(
      contentLower.contains,
    );

    return !contentHasFinancialContext;
  }
}
  enum _SummaryRole {
    sender,
    recipient,
    shared,
  }

  class _RoleFacts {
  final List<String> senderActions;
  final List<String> recipientActions;
  final List<String> sharedActions;
  final List<String> questions;

  const _RoleFacts({
    required this.senderActions,
    required this.recipientActions,
    required this.sharedActions,
    required this.questions,
  });
}
  
class _SummaryValidation {
  const _SummaryValidation({
    required this.isValid,
    required this.reason,
  });

  final bool isValid;
  final String reason;
}
class _NamedPersonAction {
  final String person;
  final String action;

  const _NamedPersonAction({
    required this.person,
    required this.action,
  });
}