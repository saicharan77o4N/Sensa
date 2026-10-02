import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Named person responsibility validation', () {
    test('detects swapped named-person responsibilities', () {
      const original = '''
Priya will prepare the slides.
Rahul will handle the backend.
The sender will test the final build.
''';

      const badSummary = '''
Rahul will prepare the slides.
Priya will handle the backend.
The sender will test the final build.
''';

      final problems = validateNamedPeople(
        original: original,
        summary: badSummary,
      );

      print('\nSWAPPED PEOPLE TEST');

      for (final problem in problems) {
        print('FAIL DETECTED: $problem');
      }

      expect(problems, isNotEmpty);
    });

    test('accepts correct named-person responsibilities', () {
      const original = '''
Priya will prepare the slides.
Rahul will handle the backend.
The sender will test the final build.
''';

      const correctSummary = '''
Priya will prepare the slides.
Rahul will handle the backend.
The sender will test the final build.
''';

      final problems = validateNamedPeople(
        original: original,
        summary: correctSummary,
      );

      print('\nCORRECT PEOPLE TEST');

      for (final problem in problems) {
        print('UNEXPECTED: $problem');
      }

      expect(problems, isEmpty);
    });
  });
}

class NamedPersonAction {
  final String person;
  final String action;

  const NamedPersonAction({
    required this.person,
    required this.action,
  });
}

List<String> validateNamedPeople({
  required String original,
  required String summary,
}) {
  final problems = <String>[];

  final originalSentences = splitSentences(original);

  for (final sentence in originalSentences) {
    final fact = extractNamedPersonAction(sentence);

    if (fact == null) {
      continue;
    }

    final segment = findBestActionSegment(
      action: fact.action,
      summary: summary,
    );

    if (segment == null) {
      continue;
    }

    final segmentLower = segment.toLowerCase();

    if (!segmentLower.contains(
      fact.person.toLowerCase(),
    )) {
      final otherPerson = findOtherNamedPerson(
        segment: segment,
        originalPerson: fact.person,
      );

      if (otherPerson != null) {
        problems.add(
          'Named person responsibility changed: '
          '${fact.person} -> $otherPerson '
          'for action: ${fact.action}',
        );
      }
    }
  }

  return problems;
}

NamedPersonAction? extractNamedPersonAction(
  String sentence,
) {
  final normalized = sentence
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

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

  return NamedPersonAction(
    person: person,
    action: action,
  );
}

String? findBestActionSegment({
  required String action,
  required String summary,
}) {
  final summarySentences = splitSentences(summary);

  if (summarySentences.isEmpty) {
    return null;
  }

  final actionWords = action
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.length >= 3)
      .map(
        (word) => word.replaceAll(
          RegExp(r'[^a-z0-9_-]'),
          '',
        ),
      )
      .where((word) => word.isNotEmpty)
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

    final score = actionWords
        .intersection(sentenceWords)
        .length;

    if (score > bestScore) {
      bestScore = score;
      bestSegment = sentence;
    }
  }

  return bestScore >= 1 ? bestSegment : null;
}

String? findOtherNamedPerson({
  required String segment,
  required String originalPerson,
}) {
  final matches = RegExp(
    r'\b[A-Z][a-zA-Z]{2,}\b',
  ).allMatches(segment);

  const ignored = {
    'The',
    'Sender',
    'Recipient',
    'Both',
    'Google',
    'Drive',
    'Meet',
  };

  for (final match in matches) {
    final candidate = match.group(0)!;

    if (candidate.toLowerCase() ==
        originalPerson.toLowerCase()) {
      continue;
    }

    if (ignored.contains(candidate)) {
      continue;
    }

    return candidate;
  }

  return null;
}

List<String> splitSentences(String content) {
  return content
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList();
}