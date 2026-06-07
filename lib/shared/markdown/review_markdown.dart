final _reviewSectionHeadings = <String>[
  '课程内容',
  '上课自由度',
  '考核标准',
  '授课质量',
  '考核方式',
  '授课质量与给分',
  '上课学期',
  '作业与考核',
  '给分情况',
  '作业量',
  '考试难度',
];

final _sectionHeadingPattern = _reviewSectionHeadings
    .map(RegExp.escape)
    .join('|');

final _invisibleMarkdownChars = RegExp(r'[\u200B\u200C\u200D\uFEFF\u2060]');
final _leadingUnicodeSpaces = RegExp(
  r'^[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]+',
);
final _indentPreserveExcludePattern = RegExp(
  r'^(#{1,6}\s|[-*+]\s|\d+\.\s|>\s?|\|.*|\*{3,}\s*$|-{3,}\s*$|_{3,}\s*$)',
);

String normalizeReviewMarkdown(String text) {
  if (text.isEmpty) return '';

  final standaloneHeadingPattern = RegExp(
    '^\\s*($_sectionHeadingPattern)[：:]?\\s*\$',
  );
  final inlineHeadingTestPattern = RegExp('($_sectionHeadingPattern)[：:]');
  final inlineHeadingReplacePattern = RegExp('($_sectionHeadingPattern)[：:]');
  final normalized = <String>[];
  var inFence = false;

  for (final originalLine
      in text.replaceAll(RegExp(r'\r\n?'), '\n').split('\n')) {
    var line = originalLine
        .replaceAll(_invisibleMarkdownChars, '')
        .replaceFirstMapped(
          _leadingUnicodeSpaces,
          (match) => ' ' * match.group(0)!.length,
        );
    final trimmedStartLine = line.trimLeft();

    if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
      inFence = !inFence;
      normalized.add(line.trimRight());
      continue;
    }

    if (inFence) {
      normalized.add(line);
      continue;
    }

    if (RegExp(r'^\s{0,3}#{1,6}\s').hasMatch(trimmedStartLine)) {
      normalized.add(trimmedStartLine.trimRight());
      continue;
    }

    final standalone = standaloneHeadingPattern.firstMatch(trimmedStartLine);
    if (standalone != null) {
      normalized.add('## ${standalone.group(1)}');
      continue;
    }

    if (inlineHeadingTestPattern.hasMatch(trimmedStartLine)) {
      normalized.add(
        trimmedStartLine
            .replaceAllMapped(
              inlineHeadingReplacePattern,
              (match) => '\n## ${match.group(1)}\n',
            )
            .replaceFirst(RegExp(r'^\n+'), '')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trimRight(),
      );
      continue;
    }

    final leadingWhitespace =
        RegExp(r'^[ \t]+').firstMatch(line)?.group(0) ?? '';
    final trimmed = line.trimLeft();
    if (leadingWhitespace.isNotEmpty &&
        trimmed.isNotEmpty &&
        !_indentPreserveExcludePattern.hasMatch(trimmed)) {
      final indentWidth = leadingWhitespace.replaceAll('\t', '    ').length;
      line = '${'&nbsp;' * indentWidth}$trimmed';
    }

    normalized.add(line.trimRight());
  }

  return normalized.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
