import 'package:flutter/material.dart';

import '../../domain/models/course.dart';
import 'rating_stars.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${course.code} · ${course.teacherName.isEmpty ? '教师待补充' : course.teacherName}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RatingStars(rating: course.rating),
                  Text(
                    course.rating > 0
                        ? '${course.rating.toStringAsFixed(1)} 分'
                        : '暂无评分',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('${course.reviewCount} 条评价'),
                  if (course.department.isNotEmpty)
                    Chip(
                      label: Text(course.department),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (course.credit > 0)
                    Chip(
                      label: Text('${course.credit.toStringAsFixed(1)} 学分'),
                      visualDensity: VisualDensity.compact,
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
