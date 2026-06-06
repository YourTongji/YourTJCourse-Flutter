import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ai_summary.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/review.dart';
import '../../shared/markdown/review_markdown.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/course_card.dart';
import '../../shared/widgets/rating_stars.dart';
import 'course_detail_controller.dart';

class CourseDetailView extends ConsumerWidget {
  const CourseDetailView({super.key, required this.courseId});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(courseDetailControllerProvider(courseId));
    final controller = ref.read(
      courseDetailControllerProvider(courseId).notifier,
    );

    return Scaffold(
      body: detail.when(
        loading: () => const LoadingState(message: '正在加载课程详情'),
        error: (error, _) =>
            ErrorState(message: error.toString(), onRetry: controller.refresh),
        data: (state) {
          final course = state.detail;
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverAppBar.large(title: Text(course.name), pinned: true),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${course.code} · ${course.teacherName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RatingStars(rating: course.rating, size: 18),
                            Text('${course.reviewCount} 条评价'),
                            if (course.department.isNotEmpty)
                              Chip(label: Text(course.department)),
                            if (course.credit > 0)
                              Chip(
                                label: Text(
                                  '${course.credit.toStringAsFixed(1)} 学分',
                                ),
                              ),
                          ],
                        ),
                        if (course.description?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 16),
                          Text(
                            course.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        if (state.aiSummary?.hasContent ?? false) ...[
                          const SizedBox(height: 16),
                          AiSummaryCard(
                            summary: state.aiSummary!,
                            onDismiss: controller.dismissSummary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '课程评价',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (state.visibleReviews.isEmpty)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: EmptyState(message: '暂无可见评价'),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: state.visibleReviews.length,
                    itemBuilder: (context, index) {
                      final review = state.visibleReviews[index];
                      return ReviewCard(
                        review: review,
                        onLike: () => controller.toggleLike(review.id),
                        onHide: () => controller.hideReview(review.id),
                        onReport: () =>
                            _showReportSheet(context, controller, review.id),
                      );
                    },
                  ),
                if (state.relatedCourses.teacherOtherCourses.isNotEmpty ||
                    state.relatedCourses.sameCourseOtherTeachers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        '相关课程',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    for (final course
                        in state.relatedCourses.teacherOtherCourses)
                      CourseCard(course: course, onTap: () {}),
                    for (final course
                        in state.relatedCourses.sameCourseOtherTeachers)
                      CourseCard(course: course, onTap: () {}),
                    const SizedBox(height: 24),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReportSheet(
    BuildContext context,
    CourseDetailController controller,
    int reviewId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final reason in ReportReason.values)
                ListTile(
                  title: Text(reason.label),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await controller.reportReview(reviewId, reason);
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text(ok ? '已提交举报' : '举报提交失败')),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    required this.summary,
    required this.onDismiss,
  });

  final AiSummaryData summary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI 课程总结', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.cancel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('综合评价', style: theme.textTheme.labelMedium),
            Text(
              summary.ratingConsensus,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (summary.keywords.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final keyword in summary.keywords)
                    Chip(label: Text(keyword)),
                ],
              ),
            ],
            _SummaryPointList(
              title: '优点',
              icon: Icons.add_circle,
              color: Colors.green,
              items: summary.pros,
            ),
            _SummaryPointList(
              title: '缺点',
              icon: Icons.remove_circle,
              color: Colors.orange,
              items: summary.cons,
            ),
            if (summary.representative.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('代表评价', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                summary.representative.first.text,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryPointList extends StatelessWidget {
  const _SummaryPointList({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.onLike,
    required this.onHide,
    required this.onReport,
  });

  final Review review;
  final VoidCallback onLike;
  final VoidCallback onHide;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    (review.reviewerName?.isNotEmpty ?? false)
                        ? review.reviewerName!.characters.first
                        : '匿',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName?.isNotEmpty ?? false
                            ? review.reviewerName!
                            : '匿名用户',
                      ),
                      Text(review.semester, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hide') onHide();
                    if (value == 'report') onReport();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'hide', child: Text('隐藏')),
                    PopupMenuItem(value: 'report', child: Text('举报')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            RatingStars(rating: review.rating.toDouble(), size: 14),
            const SizedBox(height: 8),
            MarkdownBody(data: normalizeReviewMarkdown(review.comment)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onLike,
              icon: Icon(
                review.liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
              ),
              label: Text('${review.likeCount}'),
            ),
          ],
        ),
      ),
    );
  }
}
