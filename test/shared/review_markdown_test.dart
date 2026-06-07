import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/shared/markdown/review_markdown.dart';

void main() {
  test('normalizes ICU standalone and inline section headings', () {
    final normalized = normalizeReviewMarkdown(
      '课程内容：高数为主\n上课自由度\n比较自由\n考核标准: 平时和考试',
    );

    expect(normalized, contains('## 课程内容'));
    expect(normalized, contains('## 上课自由度'));
    expect(normalized, contains('## 考核标准'));
  });

  test('keeps fenced code content unchanged', () {
    final normalized = normalizeReviewMarkdown('```\n课程内容：不要改\n```');

    expect(normalized, '```\n课程内容：不要改\n```');
  });
}
