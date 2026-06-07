import 'package:flutter/material.dart';

import '../../domain/models/course.dart';
import 'rating_stars.dart';

class CourseCard extends StatefulWidget {
  const CourseCard({super.key, required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  var _semesterExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = widget.course;
    final semesters = _orderedSemesterLabels(course.semesters);
    final recentSemester = semesters.isEmpty ? null : semesters.first;
    final historySemesters = semesters.length <= 1
        ? const <String>[]
        : semesters.sublist(1);
    final historyToShow = historySemesters.take(6).toList(growable: false);
    final omittedHistoryCount = historySemesters.length - historyToShow.length;

    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                course.code,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [
                        course.teacherName.isEmpty
                            ? '教师待补充'
                            : course.teacherName,
                        if (course.department.isNotEmpty) course.department,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RatingStars(rating: course.rating, size: 14),
                  Text(
                    course.rating > 0 ? course.rating.toStringAsFixed(1) : '-',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '(${course.reviewCount})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.book_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${course.credit.toStringAsFixed(1)} 学分',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (recentSemester != null)
                    Flexible(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _SemesterTag(label: '最近 $recentSemester'),
                              if (historySemesters.isNotEmpty)
                                _SemesterToggleTag(
                                  label: '+${historySemesters.length}',
                                  expanded: _semesterExpanded,
                                  onTap: () {
                                    setState(
                                      () => _semesterExpanded =
                                          !_semesterExpanded,
                                    );
                                  },
                                ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topRight,
                            child: _semesterExpanded
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        for (final semester in historyToShow)
                                          _SemesterTag(
                                            label: semester,
                                            subdued: true,
                                          ),
                                        if (omittedHistoryCount > 0)
                                          _SemesterTag(
                                            label: '另 $omittedHistoryCount',
                                            subdued: true,
                                          ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemesterTag extends StatelessWidget {
  const _SemesterTag({required this.label, this.subdued = false});

  final String label;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: subdued
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: subdued ? scheme.outlineVariant : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: subdued ? scheme.onSurfaceVariant : scheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SemesterToggleTag extends StatelessWidget {
  const _SemesterToggleTag({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: expanded ? '收起历史学期' : '展开历史学期',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.tertiary.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: scheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _orderedSemesterLabels(List<String> rawSemesters) {
  final labels = {
    for (final semester in rawSemesters)
      if (semester.trim().isNotEmpty) _formatSemesterLabel(semester.trim()),
  }.toList(growable: false);

  return labels.where((label) => label.trim().isNotEmpty).toList()..sort(
    (left, right) => _semesterLabelScore(right) - _semesterLabelScore(left),
  );
}

String _formatSemesterLabel(String semester) {
  final normalized = semester.trim();
  final match = RegExp(
    r'^(\d{4})-(\d{4})(?:学年第|[-])(\d+)(?:学期)?$',
  ).firstMatch(normalized);
  if (match == null) return semester;
  final fall = int.tryParse(match.group(1) ?? '');
  final spring = int.tryParse(match.group(2) ?? '');
  final term = int.tryParse(match.group(3) ?? '');
  if (fall == null || spring == null || term == null) return semester;
  if (term == 1) return '${fall.toString().substring(2)}秋';
  if (term == 2) return '${spring.toString().substring(2)}春';
  if (term == 3) return '${spring.toString().substring(2)}夏';
  return semester;
}

int _semesterLabelScore(String semester) {
  final shortMatch = RegExp(r'^(\d{2})(春|夏|秋)$').firstMatch(semester);
  if (shortMatch != null) {
    final year = 2000 + (int.tryParse(shortMatch.group(1) ?? '') ?? 0);
    final term = switch (shortMatch.group(2)) {
      '秋' => 3,
      '夏' => 2,
      '春' => 1,
      _ => 0,
    };
    return year * 10 + term;
  }

  final yearMatch = RegExp(r'^(\d{4})').firstMatch(semester);
  final year = int.tryParse(yearMatch?.group(1) ?? '') ?? 0;
  if (year == 0) return 0;
  if (semester.contains('秋') || semester.contains('第1学期')) {
    return year * 10 + 3;
  }
  if (semester.contains('夏') || semester.contains('第3学期')) {
    return year * 10 + 2;
  }
  if (semester.contains('春') || semester.contains('第2学期')) {
    return year * 10 + 1;
  }
  return year * 10;
}
