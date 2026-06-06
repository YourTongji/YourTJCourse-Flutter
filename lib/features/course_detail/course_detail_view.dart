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
                        const SizedBox(height: 16),
                        AiSummaryCard(
                          summary: state.aiSummary,
                          error: state.aiSummaryError,
                          isLoading: state.isAiSummaryLoading,
                          isExpanded: state.isAiSummaryExpanded,
                          onToggle: controller.toggleAiSummaryExpanded,
                          onLoad: () => controller.loadAiSummary(),
                          onRefresh: () =>
                              controller.loadAiSummary(refresh: true),
                        ),
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
    required this.error,
    required this.isLoading,
    required this.isExpanded,
    required this.onToggle,
    required this.onLoad,
    required this.onRefresh,
  });

  final AiSummaryData? summary;
  final String? error;
  final bool isLoading;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onLoad;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = summary;
    if (!isExpanded) {
      return OutlinedButton(
        onPressed: onToggle,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI 评课总结',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (data?.hasContent ?? false)
              _ConsensusBadge(summary: data!)
            else
              Text(
                '点击生成',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

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
                Text('AI 评课总结', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (data?.hasContent ?? false)
                  TextButton.icon(
                    onPressed: isLoading ? null : onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新'),
                  ),
                IconButton(
                  tooltip: '折叠',
                  onPressed: onToggle,
                  icon: const Icon(Icons.expand_less),
                ),
              ],
            ),
            if (isLoading)
              const _AiSummarySkeleton()
            else if (error != null && data == null)
              _AiSummaryError(message: error!, onRetry: onLoad)
            else if (data == null)
              _AiSummaryIntro(onLoad: onLoad)
            else if (!data.hasContent)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('当前评价数据不足，暂时无法生成稳定的 AI 总结。'),
              )
            else
              _AiSummaryContent(summary: data),
          ],
        ),
      ),
    );
  }
}

class _AiSummaryIntro extends StatelessWidget {
  const _AiSummaryIntro({required this.onLoad});

  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'AI 会综合学生评价整理课程特点。结果仅供快速浏览，具体判断仍建议阅读原始评价。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onLoad,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('生成 AI 总结'),
        ),
      ],
    );
  }
}

class _AiSummaryError extends StatelessWidget {
  const _AiSummaryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 总结生成失败：$message',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新尝试'),
          ),
        ],
      ),
    );
  }
}

class _AiSummarySkeleton extends StatefulWidget {
  const _AiSummarySkeleton();

  @override
  State<_AiSummarySkeleton> createState() => _AiSummarySkeletonState();
}

class _AiSummarySkeletonState extends State<_AiSummarySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(
          theme.colorScheme.primaryContainer.withValues(alpha: 0.24),
          theme.colorScheme.primaryContainer.withValues(alpha: 0.62),
          _controller.value,
        )!;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '正在思考',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _ThinkingDots(progress: _controller.value),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SkeletonBar(width: 68, height: 24, color: color),
                  _SkeletonBar(width: 96, height: 24, color: color),
                  _SkeletonBar(width: 78, height: 24, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SkeletonBlock(color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: _SkeletonBlock(color: color)),
                ],
              ),
              const SizedBox(height: 12),
              _SkeletonBar(width: double.infinity, height: 12, color: color),
              const SizedBox(height: 7),
              _SkeletonBar(width: 230, height: 12, color: color),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'AI 正在分析学生评价，请稍候...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(3, (index) {
        final value = ((progress + index / 3) % 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Opacity(
            opacity: 0.35 + value * 0.65,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox(width: 5, height: 5),
            ),
          ),
        );
      }),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBar(width: 46, height: 10, color: color),
            const SizedBox(height: 8),
            _SkeletonBar(width: double.infinity, height: 10, color: color),
            const SizedBox(height: 7),
            _SkeletonBar(width: 96, height: 10, color: color),
            const SizedBox(height: 7),
            _SkeletonBar(width: 68, height: 10, color: color),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class _AiSummaryContent extends StatelessWidget {
  const _AiSummaryContent({required this.summary});

  final AiSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}

class _ConsensusBadge extends StatelessWidget {
  const _ConsensusBadge({required this.summary});

  final AiSummaryData summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          summary.ratingConsensus,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
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
