import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/ai_summary.dart';
import '../../domain/models/course_detail.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/review_repository.dart';
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
      floatingActionButton: detail.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _showReviewSheet(context, ref, controller),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('写评价'),
            )
          : null,
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
                            Text(
                              course.rating > 0
                                  ? '${course.rating.toStringAsFixed(1)} 分'
                                  : '暂无评分',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
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
                        course: course,
                        review: review,
                        favorited: state.favoriteReviewIds.contains(review.id),
                        onLike: () => controller.toggleLike(review.id),
                        onHide: () => controller.hideReview(review.id),
                        onFavorite: () => controller.toggleFavorite(review.id),
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

  void _showReviewSheet(
    BuildContext context,
    WidgetRef ref,
    CourseDetailController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ReviewComposeSheet(
        course: controller.currentDetail,
        controller: controller,
        captchaRepository: ref.read(captchaRepositoryProvider),
      ),
    );
  }
}

class _ReviewComposeSheet extends StatefulWidget {
  const _ReviewComposeSheet({
    required this.course,
    required this.controller,
    required this.captchaRepository,
  });

  final CourseDetail course;
  final CourseDetailController controller;
  final CaptchaRepository captchaRepository;

  @override
  State<_ReviewComposeSheet> createState() => _ReviewComposeSheetState();
}

class _ReviewComposeSheetState extends State<_ReviewComposeSheet> {
  final _commentController = TextEditingController();
  final _nameController = TextEditingController();
  final _qqController = TextEditingController();
  final _avatarController = TextEditingController();
  late String _semester;
  int _rating = 0;
  bool _showReviewer = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _semester = _semesterOptions.first;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _nameController.dispose();
    _qqController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  List<String> get _semesterOptions {
    final semesters = [
      for (final semester in widget.course.semesters)
        if (semester.trim().isNotEmpty) semester.trim(),
    ];
    return [...semesters.toSet(), '其他'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final valid = _rating > 0 && _commentController.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('写评价', style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _rating = star),
                      icon: Icon(
                        star <= _rating ? Icons.star : Icons.star_border,
                        color: star <= _rating
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                minLines: 5,
                maxLines: 8,
                maxLength: 10000,
                decoration: const InputDecoration(
                  labelText: '评价内容',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _semester,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '学期'),
                items: [
                  for (final option in _semesterOptions)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _semester = value ?? '其他'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示点评人信息'),
                subtitle: const Text('可填写昵称和头像，字段与网页版保持一致'),
                value: _showReviewer,
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _showReviewer = value),
              ),
              if (_showReviewer) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '昵称'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _qqController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'QQ 号（选填）',
                    hintText: '填写后使用 QQ 头像',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _avatarController,
                  decoration: const InputDecoration(
                    labelText: '头像链接（选填）',
                    hintText: '优先使用头像链接，其次使用 QQ 头像',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: valid && !_isSubmitting ? _submit : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(_isSubmitting ? '提交中...' : '验证并提交'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final captchaToken = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _CaptchaSheet(captchaRepository: widget.captchaRepository),
    );
    if (captchaToken == null || captchaToken.isEmpty || !mounted) return;
    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.controller.createReview(
      rating: _rating,
      comment: _commentController.text.trim(),
      semester: _semester,
      captchaToken: captchaToken,
      reviewerName: _showReviewer ? _nameController.text.trim() : null,
      reviewerAvatar: _showReviewer ? _reviewerAvatar : null,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('评价提交成功')));
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('评价提交失败，请稍后重试')));
  }

  String? get _reviewerAvatar {
    final direct = _avatarController.text.trim();
    if (direct.isNotEmpty) return direct;
    final qq = _qqController.text.trim();
    if (qq.isEmpty) return null;
    return 'https://q1.qlogo.cn/g?b=qq&nk=$qq&s=100';
  }
}

class _CaptchaSheet extends ConsumerStatefulWidget {
  const _CaptchaSheet({required this.captchaRepository});

  final CaptchaRepository captchaRepository;

  @override
  ConsumerState<_CaptchaSheet> createState() => _CaptchaSheetState();
}

class _CaptchaSheetState extends ConsumerState<_CaptchaSheet> {
  CaptchaChallenge? _challenge;
  final Set<int> _selected = {};
  String? _message;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
      _selected.clear();
    });
    try {
      final challenge = await widget.captchaRepository.fetchChallenge();
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '验证码加载失败，请重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = _challenge;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOURTJ 人机验证', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              challenge?.prompt ?? '请选择符合条件的图片',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (challenge == null)
              SizedBox(
                height: 140,
                child: Center(child: Text(_message ?? '验证码不可用')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: challenge.images.length,
                itemBuilder: (context, index) {
                  final selected = _selected.contains(index);
                  return InkWell(
                    onTap: _verifying
                        ? null
                        : () => setState(() {
                            selected
                                ? _selected.remove(index)
                                : _selected.add(index);
                          }),
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            challenge.images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (selected)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.38,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loading || _verifying ? null : _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('换一组'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _verifying
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed:
                      challenge == null || _selected.isEmpty || _verifying
                      ? null
                      : _verify,
                  child: Text(_verifying ? '验证中...' : '确认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null) return;
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final response = await widget.captchaRepository.verify(
        puzzleToken: challenge.puzzleToken,
        selectedIndices: _selected.toList(growable: false)..sort(),
      );
      if (!mounted) return;
      if (response.success && (response.token?.isNotEmpty ?? false)) {
        Navigator.of(context).pop(response.token);
        return;
      }
      setState(() {
        _message = response.message ?? '验证失败，请重试';
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = '网络错误，请重试';
        _verifying = false;
      });
    }
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
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.54,
        ),
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
    required this.course,
    required this.review,
    required this.favorited,
    required this.onLike,
    required this.onHide,
    required this.onFavorite,
    required this.onReport,
  });

  final CourseDetail course;
  final Review review;
  final bool favorited;
  final VoidCallback onLike;
  final VoidCallback onHide;
  final VoidCallback onFavorite;
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
                ReviewAvatar(review: review, size: 46),
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
                    if (value == 'share') {
                      showReviewShareDialog(
                        context,
                        course: course,
                        review: review,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'share', child: Text('生成分享图')),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onLike,
                  icon: Icon(
                    review.liked
                        ? Icons.thumb_up_alt
                        : Icons.thumb_up_alt_outlined,
                  ),
                  label: Text('${review.likeCount}'),
                ),
                TextButton.icon(
                  onPressed: onFavorite,
                  icon: Icon(
                    favorited ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  label: Text(favorited ? '已收藏' : '收藏'),
                ),
                TextButton.icon(
                  onPressed: () => showReviewShareDialog(
                    context,
                    course: course,
                    review: review,
                  ),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('分享图'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewAvatar extends StatelessWidget {
  const ReviewAvatar({super.key, required this.review, this.size = 44});

  final Review review;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = review.reviewerAvatar?.trim() ?? '';
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Text(
          (review.reviewerName?.isNotEmpty ?? false)
              ? review.reviewerName!.characters.first
              : '匿',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: size,
        child: avatar.startsWith('http')
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

Future<void> showReviewShareDialog(
  BuildContext context, {
  required CourseDetail course,
  required Review review,
}) async {
  final key = GlobalKey();
  String? savedPath;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('课程点评分享图'),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: ReviewShareCard(course: course, review: review),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              savedPath = await saveReviewShareImage(key, course, review);
              if (!context.mounted) return;
              messenger.showSnackBar(SnackBar(content: Text('已保存：$savedPath')));
            },
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('保存'),
          ),
          FilledButton.tonalIcon(
            onPressed: () async {
              final path =
                  savedPath ?? await saveReviewShareImage(key, course, review);
              await SharePlus.instance.share(
                ShareParams(
                  files: [XFile(path, mimeType: 'image/png')],
                  text: '来自 YourTJ 选课社区的课程点评',
                ),
              );
            },
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('分享'),
          ),
        ],
      );
    },
  );
}

Future<String> saveReviewShareImage(
  GlobalKey key,
  CourseDetail course,
  Review review,
) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('分享图尚未渲染');
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final data = bytes?.buffer.asUint8List();
  if (data == null) throw StateError('分享图生成失败');
  final directory = await getApplicationDocumentsDirectory();
  final safeCode = course.code.isEmpty ? 'yourtj' : course.code;
  final file = File('${directory.path}/$safeCode-${review.sqid}.png');
  await file.writeAsBytes(data, flush: true);
  return file.path;
}

class ReviewShareCard extends StatelessWidget {
  const ReviewShareCard({
    super.key,
    required this.course,
    required this.review,
  });

  final CourseDetail course;
  final Review review;

  @override
  Widget build(BuildContext context) {
    final reviewerName = (review.reviewerName?.trim().isNotEmpty ?? false)
        ? review.reviewerName!.trim()
        : '匿名用户';
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 760,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOURTJ 选课社区',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            course.name,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 30,
                              height: 1.16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SharePill(
                            text: course.code,
                            foreground: Colors.white,
                            background: const Color(0xFF0F172A),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '课程评分',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              course.rating > 0
                                  ? '${course.rating.toStringAsFixed(1)} / 5.0'
                                  : '- / 5.0',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${course.reviewCount} 条评价',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    ReviewAvatar(review: review, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewerName,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${review.semester} · ${_formatReviewDate(review.createdAt)}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SharePill(
                      text: '${review.rating.toStringAsFixed(1)} / 5',
                      foreground: const Color(0xFFD97706),
                      background: const Color(0xFFFFFBEB),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SharePill(
                      text:
                          '教师：${course.teacherName.isEmpty ? '未知教师' : course.teacherName}',
                      foreground: const Color(0xFF0E7490),
                      background: const Color(0xFFECFEFF),
                    ),
                    _SharePill(
                      text: '学期：${review.semester}',
                      foreground: const Color(0xFF4338CA),
                      background: const Color(0xFFEEF2FF),
                    ),
                    _SharePill(
                      text: '编号：${review.sqid}',
                      foreground: const Color(0xFF047857),
                      background: const Color(0xFFECFDF5),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      review.comment,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 17,
                        height: 1.72,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '内容来自 YOURTJ 选课社区',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'xk.yourtj.de',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  const _SharePill({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: Text(
          text,
          style: TextStyle(
            color: foreground,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String _formatReviewDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  final timestamp = int.tryParse(raw);
  final date =
      parsed ??
      (timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
  if (date == null) return raw.isEmpty ? '刚刚' : raw;
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
