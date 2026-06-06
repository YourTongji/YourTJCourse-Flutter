import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
