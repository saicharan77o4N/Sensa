import 'package:flutter_test/flutter_test.dart';
import 'package:sensa/generative_ai_service.dart';

void main() {
  test('production validator rejects a bad summary', () {
    final service = GenerativeAiService.instance;

    const original = '''
Can you send me the report? I'll review it after lunch and we can go through the results together.
''';

    const badSummary = '''
The sender will send the report and the recipient will review it after lunch.
''';

    final result = service.debugValidateSummary(
      originalContent: original,
      summary: badSummary,
    );

    print('\n=== BAD QWEN SUMMARY ===');
    print(result);

    expect(result, startsWith('FAIL:'));
  });

  test('production validator accepts a safe summary', () {
    final service = GenerativeAiService.instance;

    const original = '''
Can you send me the report? I'll review it after lunch and we can go through the results together.
''';

    const safeSummary = '''
Can you send me the report? The sender will review it after lunch, and both will go through the results together.
''';

    final result = service.debugValidateSummary(
      originalContent: original,
      summary: safeSummary,
    );

    print('\n=== SAFE SUMMARY ===');
    print(result);

    expect(result, 'PASS');
  });
}