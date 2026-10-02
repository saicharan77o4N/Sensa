enum FactRole {
  sender,
  recipient,
  shared,
  thirdParty,
  question,
  context,
}

class StructuredFact {
  final FactRole role;
  final String text;
  final String? person;
  final String source;

  const StructuredFact({
    required this.role,
    required this.text,
    this.person,
    required this.source,
  });

  @override
  String toString() {
    final roleName = role.name.toUpperCase();
    final personPart = person == null ? '' : ' | person=$person';

    return '$roleName$personPart | text="$text"';
  }
}

void main() {
  const tests = [
    // 1. Simple recipient request
    'Please send me the database schema before lunch.',

    // 2. Question + sender action
    'Can you send me the report? I will review it after lunch.',

    // 3. Question + sender + shared
    'Can you finish the API documentation by tomorrow? '
        'I will handle the frontend deck and we can sync at 4pm.',

    // 4. Shared + sender
    'We should include the bug statistics, but I will prepare the presentation.',

    // 5. Shared action
    'Let us send the report after we review it together.',

    // 6. Recipient + sender
    'You finish the backend integration and I will prepare the frontend.',

    // 7. Third party + sender
    'Priya asked me to send the report to Rahul.',

    // 8. Third party + recipient
    'Rahul said you should submit the assignment by Friday.',

    // 9. Multiple sender/shared facts
    'I did not finish my slides yet. I will share the template on Drive. '
        'We should include the bug-fix statistics.',

    // 10. Question + multiple sender facts + context
    'Are you joining the OKR planning meeting at 11? '
        'I did not finish my slides yet and I was looking for the template. '
        'It is the same one we used last quarter, I will share it on Drive.',

    // 11. Money/payment
    'The electricity bill is ₹2,450 and it is due tomorrow. I will pay it tonight.',

    // 12. Delivery
    'Your package will arrive tomorrow between 2 PM and 5 PM. '
        'Please keep your phone available for the delivery call.',

    // 13. Security
    'Your login verification code is 482913. Do not share this code with anyone.',

    // 14. Meeting
    'The client meeting has moved to Friday at 3 PM. '
        'Can you prepare the demo before then?',

    // 15. Work delegation
    'I will update the database migration scripts, and you can test them after lunch.',

    // 16. Multiple people
    'Priya will prepare the slides, Rahul will handle the backend, '
        'and I will test the final build.',
        // 16A. Named person actions
        'Priya will prepare the slides.',
        'Rahul will handle the backend.',
        'Arjun needs to review the pull request.',
        'Sandeep can deploy the server.',

    // 17. Shared decision
    'We decided to submit the project on Monday after we finish the final testing.',

    // 18. Personal message
    'Mom asked if you are coming home tonight. '
        'I told her you might arrive after 9.',

    // 19. Mixed question + shared action
    'Could you check the presentation? '
        'We can review the changes together at 6 PM.',

    // 20. Longer mixed notification
    'The deployment failed because the database migration was incomplete. '
        'I will fix the migration now, and you can verify the API afterward. '
        'Let us deploy again at 5 PM if everything passes.',
    ];

  for (var i = 0; i < tests.length; i++) {
    print('');
    print('========== TEST ${i + 1} ==========');
    print('INPUT:');
    print(tests[i]);
    print('');
    print('STRUCTURED FACTS:');

    final facts = extractStructuredFacts(tests[i]);

    if (facts.isEmpty) {
      print('(none)');
    } else {
      for (final fact in facts) {
        print('- $fact');
      }
    }
  }
}

List<StructuredFact> extractStructuredFacts(String content) {
  final facts = <StructuredFact>[];

  final sentences = splitSentences(content);

  for (final sentence in sentences) {
    final trimmed = sentence.trim();

    if (trimmed.isEmpty) {
      continue;
    }

    // Preserve the complete original question separately.
    if (looksLikeQuestion(trimmed)) {
    final questionFacts = extractQuestionFacts(trimmed);

    facts.addAll(questionFacts);

    // The question has already been classified.
    continue;
    }

    final clauses = splitClauses(trimmed);

    for (final clause in clauses) {
      var text = cleanClause(clause);

      if (text.isEmpty) {
        continue;
      }

      final lower = text.toLowerCase();
      // ----------------------------------------------------------
        // NAMED PERSON ACTION
        // ----------------------------------------------------------
        //
        // Examples:
        // "Priya will prepare the slides."
        // "Rahul will handle the backend."
        // "Arjun needs to review the pull request."
        // "Sandeep can deploy the server."
        //
        // Do not treat pronouns such as "we" or "you"
        // as named people.
        final namedPersonMatch = RegExp(
        r'^([A-Z][a-z]+)\s+'
        r'(will|can|should|needs to|has to|must|is going to)\s+(.+)$',
        ).firstMatch(text);

        if (namedPersonMatch != null) {
        final person = namedPersonMatch.group(1)?.trim();
        final action = namedPersonMatch.group(3)?.trim();

        final personLower = person?.toLowerCase();

        const excludedPronouns = {
            'i',
            'you',
            'we',
            'they',
            'he',
            'she',
            'it',
        };

        if (person != null &&
            personLower != null &&
            !excludedPronouns.contains(personLower) &&
            action != null &&
            action.isNotEmpty) {
            facts.add(
            StructuredFact(
                role: FactRole.thirdParty,
                person: person,
                text: cleanClause(action),
                source: text,
            ),
            );

            continue;
        }
        }

      // ----------------------------------------------------------
      // THIRD-PERSON / NAMED PERSON
      // ----------------------------------------------------------

      final thirdPartyMatch = RegExp(
        r'^([A-Z][a-z]+)\s+(asked|told|said|mentioned|requested)\s+(.+)$',
      ).firstMatch(text);

      if (thirdPartyMatch != null) {
        final person = thirdPartyMatch.group(1)!;
        final verb = thirdPartyMatch.group(2)!;
        final remainder = thirdPartyMatch.group(3)!;

        facts.add(
          StructuredFact(
            role: FactRole.thirdParty,
            person: person,
            text: '$verb $remainder',
            source: text,
          ),
        );

        // Example:
        // Rahul said you should submit the assignment by Friday.
        final recipientMatch = RegExp(
            r"\byou\s+(?:should|need to|have to|must|will|'ll)\s+(.+)",
            caseSensitive: false,
            ).firstMatch(remainder);

        if (recipientMatch != null) {
          facts.add(
            StructuredFact(
              role: FactRole.recipient,
              text: cleanClause(recipientMatch.group(1)!),
              source: text,
            ),
          );
        }

        // Example:
        // Priya asked me to send the report.
        final senderMatch = RegExp(
          r'\bme\s+to\s+(.+)',
          caseSensitive: false,
        ).firstMatch(remainder);

        if (senderMatch != null) {
          facts.add(
            StructuredFact(
              role: FactRole.sender,
              text: cleanClause(senderMatch.group(1)!),
              source: text,
            ),
          );
        }

        continue;
      }

      // ----------------------------------------------------------
      // SHARED
      // ----------------------------------------------------------

      final sharedMatch = RegExp(
        r"^(we|let's|let us|lets|us)\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(text);

      if (sharedMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.shared,
            text: cleanClause(sharedMatch.group(2)!),
            source: text,
          ),
        );

        continue;
      }

      // ----------------------------------------------------------
      // RECIPIENT — "Can you...", "Could you..."
      // ----------------------------------------------------------

      final recipientQuestionMatch = RegExp(
        r'^(?:please\s+)?(?:can|could|would|will)\s+you\s+(.+?)[?]?$',
        caseSensitive: false,
      ).firstMatch(text);

      if (recipientQuestionMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.recipient,
            text: cleanClause(recipientQuestionMatch.group(1)!),
            source: text,
          ),
        );

        continue;
      }

      // ----------------------------------------------------------
      // RECIPIENT — "You should...", "You need..."
      // ----------------------------------------------------------

      final directYouMatch = RegExp(
        r"^you\s+(?:should|need to|have to|must|will|'ll)\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(text);

      if (directYouMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.recipient,
            text: cleanClause(directYouMatch.group(1)!),
            source: text,
          ),
        );

        continue;
      }

      // ----------------------------------------------------------
      // RECIPIENT — direct imperative
      //
      // "You finish the backend integration"
      // ----------------------------------------------------------

      final directImperativeMatch = RegExp(
        r'^you\s+([a-z]+(?:\s+.+)?)$',
        caseSensitive: false,
      ).firstMatch(text);

      if (directImperativeMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.recipient,
            text: cleanClause(directImperativeMatch.group(1)!),
            source: text,
          ),
        );

        continue;
      }
      // RECIPIENT — negative instructions
        //
        // Examples:
        // "Do not share this code."
        // "Don't forget the meeting."
        // "Never send the password."
        // "Please don't upload the file."
        final negativeInstructionMatch = RegExp(
        r"^(?:please\s+)?(?:do\s+not|don't|never)\s+(.+)$",
        caseSensitive: false,
        ).firstMatch(text);

        if (negativeInstructionMatch != null) {
        facts.add(
            StructuredFact(
            role: FactRole.recipient,
            text: 'not ${cleanClause(negativeInstructionMatch.group(1)!)}',
            source: text,
            ),
        );

        continue;
        }
      // ----------------------------------------------------------
      // POLITE IMPERATIVE
      // ----------------------------------------------------------

      if (lower.startsWith('please ')) {
        facts.add(
          StructuredFact(
            role: FactRole.recipient,
            text: cleanClause(text.substring(7)),
            source: text,
          ),
        );

        continue;
      }

      // ----------------------------------------------------------
      // SENDER
      // ----------------------------------------------------------

      final senderMatch = RegExp(
        r"^I\s+(?:will|'ll|am|'m|have|'ve|need to|can)\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(text);

      if (senderMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.sender,
            text: cleanClause(senderMatch.group(1)!),
            source: text,
          ),
        );

        continue;
      }

      // General first-person statement.
      final senderGeneralMatch = RegExp(
        r'^I\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(text);

      if (senderGeneralMatch != null) {
        facts.add(
          StructuredFact(
            role: FactRole.sender,
            text: cleanClause(senderGeneralMatch.group(1)!),
            source: text,
          ),
        );

        continue;
      }

      // ----------------------------------------------------------
      // GENERAL CONTEXT
      // ----------------------------------------------------------

      facts.add(
        StructuredFact(
          role: FactRole.context,
          text: text,
          source: text,
        ),
      );
    }
  }

  return deduplicateFacts(facts);
}

List<StructuredFact> extractQuestionFacts(String text) {
  final facts = <StructuredFact>[];

  // Always preserve the original question.
  facts.add(
    StructuredFact(
      role: FactRole.question,
      text: text,
      source: text,
    ),
  );

  // Questions directed at the recipient often contain an action.
  // Example:
  // "Can you send me the report?"
  // → RECIPIENT: "send me the report"
  final recipientMatch = RegExp(
    r'^(?:please\s+)?(?:can|could|would|will)\s+you\s+(.+?)[?]?$',
    caseSensitive: false,
  ).firstMatch(text.trim());

  if (recipientMatch != null) {
    final action = recipientMatch.group(1)?.trim();

    if (action != null && action.isNotEmpty) {
      facts.add(
        StructuredFact(
          role: FactRole.recipient,
          text: action,
          source: text,
        ),
      );
    }
  }

  return facts;
}

List<String> splitSentences(String content) {
  return content
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList();
}

List<String> splitClauses(String sentence) {
  var working = sentence.trim();

  // Split comma + first-person action.
  //
  // "It is the same one we used last quarter,
  //  I will share it on Drive."
  working = working.replaceAllMapped(
    RegExp(
      r",\s+(?=I\s+(?:will|'ll|am|'m|have|'ve|can|need))",
      caseSensitive: false,
    ),
    (_) => '|CLAUSE|',
  );
    // Split comma-separated named-person actions.
    //
    // Examples:
    // "Priya will prepare the slides, Rahul will handle the backend"
    // ->
    // "Priya will prepare the slides"
    // "Rahul will handle the backend"
    working = working.replaceAllMapped(
    RegExp(
        r',\s+(?=[A-Z][a-z]+\s+'
        r'(?:will|can|should|needs to|has to|must|is going to)\s+)',
    ),
    (_) => '|CLAUSE|',
    );

  // Split conjunctions that usually introduce a new fact.
  //
  // Do NOT split on every "and".
  // This preserves phrases such as:
  // "between 2 PM and 5 PM"
  working = working.replaceAllMapped(
    RegExp(
    r'\s+(?:but|while|because|so|then|and)\s+'
    r'(?!(?:\d{1,2}(?::\d{2})?\s*(?:AM|PM)\b))',
    caseSensitive: false,
    ),
    (_) => '|CLAUSE|',
  );

  return working
      .split('|CLAUSE|')
      .map((clause) => clause.trim())
      .where((clause) => clause.isNotEmpty)
      .toList();
}

String cleanClause(String text) {
  return text
      .trim()
      .replaceFirst(RegExp(r'[,.!?]+$'), '')
      .trim();
}

bool looksLikeQuestion(String text) {
  return text.trim().endsWith('?');
}

List<StructuredFact> deduplicateFacts(
  List<StructuredFact> facts,
) {
  final seen = <String>{};
  final result = <StructuredFact>[];

  for (final fact in facts) {
    final key = [
      fact.role.name,
      fact.person ?? '',
      fact.text.toLowerCase(),
    ].join('|');

    if (seen.add(key)) {
      result.add(fact);
    }
  }

  return result;
}