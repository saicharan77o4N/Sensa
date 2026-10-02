import 'package:flutter_test/flutter_test.dart';
import 'package:sensa/generative_ai_service.dart';

void main() {
  test('production validator detects named-person responsibility swap', () {
    final service = GenerativeAiService.instance;

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

    final result = service.debugValidateSummary(
      originalContent: original,
      summary: badSummary,
    );

    print('\n=== PRODUCTION VALIDATOR — BAD SUMMARY ===');
    print(result);

    expect(result, startsWith('FAIL:'));
  });

  test('production validator accepts correct named-person responsibilities', () {
    final service = GenerativeAiService.instance;

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

    final result = service.debugValidateSummary(
      originalContent: original,
      summary: correctSummary,
    );

    print('\n=== PRODUCTION VALIDATOR — CORRECT SUMMARY ===');
    print(result);

    expect(result, 'PASS');
  });
}