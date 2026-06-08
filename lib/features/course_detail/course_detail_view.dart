import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
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
                      CourseCard(
                        course: course,
                        onTap: () => context.push('/course/${course.id}'),
                      ),
                    for (final course
                        in state.relatedCourses.sameCourseOtherTeachers)
                      CourseCard(
                        course: course,
                        onTap: () => context.push('/course/${course.id}'),
                      ),
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
  late String _semester;
  int _rating = 0;
  bool _showReviewer = false;
  _ReviewerAvatarType _avatarType = _ReviewerAvatarType.random;
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
                subtitle: const Text('可填写昵称，并选择随机头像或 QQ 头像'),
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
                SegmentedButton<_ReviewerAvatarType>(
                  segments: const [
                    ButtonSegment(
                      value: _ReviewerAvatarType.random,
                      label: Text('随机头像'),
                      icon: Icon(Icons.auto_awesome_outlined),
                    ),
                    ButtonSegment(
                      value: _ReviewerAvatarType.qq,
                      label: Text('QQ头像'),
                      icon: Icon(Icons.account_circle_outlined),
                    ),
                  ],
                  selected: {_avatarType},
                  onSelectionChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _avatarType = value.single),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ReviewAvatar(
                      review: Review(
                        id: 0,
                        sqid: 'preview',
                        courseId: widget.course.id,
                        semester: _semester,
                        rating: _rating,
                        comment: _commentController.text,
                        createdAt: DateTime.now().toIso8601String(),
                        likeCount: 0,
                        liked: false,
                        reviewerName: _nameController.text.trim(),
                        reviewerAvatar: _reviewerAvatar,
                      ),
                      size: 46,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _avatarType == _ReviewerAvatarType.qq
                            ? '我们只保存头像链接，不会公开你的 QQ 号'
                            : '随机头像按昵称生成',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_avatarType == _ReviewerAvatarType.qq) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qqController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'QQ 号',
                      hintText: '输入 QQ 号生成头像',
                    ),
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      if (digits != value) {
                        _qqController.value = TextEditingValue(
                          text: digits,
                          selection: TextSelection.collapsed(
                            offset: digits.length,
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ],
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
    if (_avatarType != _ReviewerAvatarType.qq) return null;
    final qq = _qqController.text.trim();
    if (qq.isEmpty) return null;
    return 'https://q1.qlogo.cn/g?b=qq&nk=$qq&s=640';
  }
}

enum _ReviewerAvatarType { random, qq }

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
    final seed = (review.reviewerName?.trim().isNotEmpty ?? false)
        ? review.reviewerName!.trim()
        : '评论长图-${review.id}';
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(
        painter: _BeamAvatarPainter(seed: seed),
        child: const SizedBox.expand(),
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

class _BeamAvatarPainter extends CustomPainter {
  const _BeamAvatarPainter({required this.seed});

  static const _colors = [
    Color(0xFF0F172A),
    Color(0xFF38BDF8),
    Color(0xFFF8FAFC),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
  ];

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final data = _BeamAvatarData(seed: seed, colors: _colors);
    final scale = size.shortestSide / _BeamAvatarData.canvasSize;
    final dx = (size.width - size.shortestSide) / 2;
    final dy = (size.height - size.shortestSide) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.clipPath(
      Path()..addOval(
        const Rect.fromLTWH(
          0,
          0,
          _BeamAvatarData.canvasSize,
          _BeamAvatarData.canvasSize,
        ),
      ),
    );

    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        0,
        _BeamAvatarData.canvasSize,
        _BeamAvatarData.canvasSize,
      ),
      Paint()..color = data.backgroundColor,
    );

    canvas.save();
    canvas.translate(data.wrapperTranslateX, data.wrapperTranslateY);
    canvas.translate(18, 18);
    canvas.rotate(data.wrapperRotate * math.pi / 180);
    canvas.translate(-18, -18);
    canvas.scale(data.wrapperScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(
          0,
          0,
          _BeamAvatarData.canvasSize,
          _BeamAvatarData.canvasSize,
        ),
        Radius.circular(data.isCircle ? _BeamAvatarData.canvasSize : 6),
      ),
      Paint()..color = data.wrapperColor,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(data.faceTranslateX, data.faceTranslateY);
    canvas.translate(18, 18);
    canvas.rotate(data.faceRotate * math.pi / 180);
    canvas.translate(-18, -18);

    final facePaint = Paint()..color = data.faceColor;
    final mouthY = 19.0 + data.mouthSpread;
    if (data.isMouthOpen) {
      final path = Path()
        ..moveTo(15, mouthY)
        ..cubicTo(17, mouthY + 1, 19, mouthY + 1, 21, mouthY);
      canvas.drawPath(
        path,
        Paint()
          ..color = data.faceColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(13, mouthY - 0.75, 10, 1.5),
        0,
        math.pi,
        false,
        facePaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 - data.eyeSpread, 14, 1.5, 2),
        const Radius.circular(1),
      ),
      facePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20 + data.eyeSpread, 14, 1.5, 2),
        const Radius.circular(1),
      ),
      facePaint,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeamAvatarPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _BeamAvatarData {
  _BeamAvatarData({required String seed, required List<Color> colors}) {
    final hash = _hashCode(seed.isEmpty ? '匿名用户' : seed);
    final length = colors.length;
    wrapperColor = _colorAt(hash, colors, length);
    faceColor = _readableFaceColor(wrapperColor);
    backgroundColor = _colorAt(hash + 13, colors, length);

    final tx = _getUnit(hash, 10, 1);
    wrapperTranslateX = tx < 5 ? tx + canvasSize / 9 : tx.toDouble();
    final ty = _getUnit(hash, 10, 2);
    wrapperTranslateY = ty < 5 ? ty + canvasSize / 9 : ty.toDouble();

    wrapperRotate = _getUnit(hash, 360).toDouble();
    wrapperScale = 1 + _getUnit(hash, canvasSize ~/ 12) / 10;
    isMouthOpen = _bool(hash, 2);
    isCircle = _bool(hash, 1);
    eyeSpread = _getUnit(hash, 5).toDouble();
    mouthSpread = _getUnit(hash, 3).toDouble();
    faceRotate = _getUnit(hash, 10, 3).toDouble();
    faceTranslateX = wrapperTranslateX > canvasSize / 6
        ? wrapperTranslateX / 2
        : _getUnit(hash, 8, 1).toDouble();
    faceTranslateY = wrapperTranslateY > canvasSize / 6
        ? wrapperTranslateY / 2
        : _getUnit(hash, 7, 2).toDouble();
  }

  static const canvasSize = 36.0;

  late final Color wrapperColor;
  late final Color faceColor;
  late final Color backgroundColor;
  late final double wrapperTranslateX;
  late final double wrapperTranslateY;
  late final double wrapperRotate;
  late final double wrapperScale;
  late final bool isMouthOpen;
  late final bool isCircle;
  late final double eyeSpread;
  late final double mouthSpread;
  late final double faceRotate;
  late final double faceTranslateX;
  late final double faceTranslateY;

  static int _hashCode(String name) {
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = ((hash << 5) - hash + unit).toSigned(32);
    }
    return hash.abs();
  }

  static int _digit(int number, int n) {
    return (number / math.pow(10, n)).floor() % 10;
  }

  static bool _bool(int number, int n) {
    return _digit(number, n).isEven;
  }

  static int _getUnit(int number, int range, [int? index]) {
    final value = number % range;
    return index != null && _digit(number, index).isEven ? -value : value;
  }

  static Color _colorAt(int number, List<Color> colors, int length) {
    return colors[number % length];
  }

  static Color _readableFaceColor(Color color) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    final luminance = (red * 299 + green * 587 + blue * 114) / 1000;
    return luminance >= 128 ? Colors.black : Colors.white;
  }
}

Future<ui.Image?> _loadShareAvatarImage(Review review) async {
  final avatarUrl = review.reviewerAvatar?.trim() ?? '';
  if (!avatarUrl.startsWith('http')) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final uri = Uri.parse(avatarUrl);
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final bytes = await consolidateHttpClientResponseBytes(response);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

class _ReviewShareImagePainter {
  const _ReviewShareImagePainter({
    required this.course,
    required this.review,
    required this.avatar,
  });

  static const width = 640.0;
  static const _padding = 28.0;
  static const _contentWidth = width - _padding * 2;

  final CourseDetail course;
  final Review review;
  final ui.Image? avatar;

  Size measure() {
    final title = _measureText(
      course.name,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 27,
        height: 1.16,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 380,
      maxLines: 3,
    );
    final commentBlocks = _parseShareMarkdown(review.comment);
    final commentHeight = _measureMarkdownBlocks(
      commentBlocks,
      maxWidth: _contentWidth - 44,
    );
    final chipsHeight = _measurePills([
      '教师：${course.teacherName.isEmpty ? '未知教师' : course.teacherName}',
      '学期：${review.semester}',
      '编号：${review.sqid}',
    ], _contentWidth).height;

    final headerHeight = math.max(116, 13 + 12 + title.height + 12 + 31);
    final height =
        _padding +
        headerHeight +
        26 +
        58 +
        18 +
        chipsHeight +
        22 +
        commentHeight +
        44 +
        22 +
        18 +
        _padding;
    return Size(width, height.ceilToDouble());
  }

  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = Colors.white;
    final border = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      background,
    );

    var y = _padding;
    final titlePainter = _layoutText(
      course.name,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 27,
        height: 1.16,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: 380,
      maxLines: 3,
    );

    _paintText(
      canvas,
      'YOURTJ 选课社区',
      const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.8,
      ),
      Offset(_padding, y),
      maxWidth: 380,
    );
    y += 25;
    titlePainter.paint(canvas, Offset(_padding, y));
    y += titlePainter.height + 12;
    _paintPill(
      canvas,
      course.code,
      Offset(_padding, y),
      foreground: Colors.white,
      background: const Color(0xFF0F172A),
    );

    _paintRatingBox(
      canvas,
      Rect.fromLTWH(width - _padding - 150, _padding, 150, 108),
      border,
    );
    y = math.max(_padding + 116, y + 31);

    y += 26;
    _paintAvatar(canvas, Rect.fromLTWH(_padding, y, 58, 58));
    final reviewerName = (review.reviewerName?.trim().isNotEmpty ?? false)
        ? review.reviewerName!.trim()
        : '匿名用户';
    _paintText(
      canvas,
      reviewerName,
      const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      Offset(_padding + 72, y + 5),
      maxWidth: 330,
    );
    _paintText(
      canvas,
      '${review.semester} · ${_formatReviewDate(review.createdAt)}',
      const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      Offset(_padding + 72, y + 34),
      maxWidth: 330,
    );
    _paintPill(
      canvas,
      '${review.rating.toStringAsFixed(1)} / 5',
      Offset(width - _padding - 80, y + 13),
      foreground: const Color(0xFFD97706),
      background: const Color(0xFFFFFBEB),
    );

    y += 76;
    y = _paintPillWrap(
      canvas,
      [
        _ShareImagePill(
          text:
              '教师：${course.teacherName.isEmpty ? '未知教师' : course.teacherName}',
          foreground: const Color(0xFF0E7490),
          background: const Color(0xFFECFEFF),
        ),
        _ShareImagePill(
          text: '学期：${review.semester}',
          foreground: const Color(0xFF4338CA),
          background: const Color(0xFFEEF2FF),
        ),
        _ShareImagePill(
          text: '编号：${review.sqid}',
          foreground: const Color(0xFF047857),
          background: const Color(0xFFECFDF5),
        ),
      ],
      Offset(_padding, y),
      maxWidth: _contentWidth,
    );

    y += 22;
    final commentBlocks = _parseShareMarkdown(review.comment);
    final commentHeight = _measureMarkdownBlocks(
      commentBlocks,
      maxWidth: _contentWidth - 44,
    );
    final commentRect = Rect.fromLTWH(
      _padding,
      y,
      _contentWidth,
      commentHeight + 44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(commentRect, const Radius.circular(22)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(commentRect, const Radius.circular(22)),
      Paint()
        ..color = const Color(0xFFBAE6FD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _paintMarkdownBlocks(
      canvas,
      commentBlocks,
      Offset(_padding + 22, y + 22),
      maxWidth: _contentWidth - 44,
    );
    y += commentRect.height + 22;

    _paintText(
      canvas,
      '内容来自 YOURTJ 选课社区',
      const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      Offset(_padding, y),
      maxWidth: 300,
    );
    _paintText(
      canvas,
      'xk.yourtj.de',
      const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      Offset(width - _padding - 82, y),
      maxWidth: 90,
    );
  }

  void _paintRatingBox(Canvas canvas, Rect rect, Paint border) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      border,
    );
    _paintText(
      canvas,
      '课程评分',
      const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      Offset(rect.right - 82, rect.top + 17),
      maxWidth: 80,
      textAlign: TextAlign.right,
    );
    _paintText(
      canvas,
      course.rating > 0
          ? '${course.rating.toStringAsFixed(1)} / 5.0'
          : '- / 5.0',
      const TextStyle(
        color: Color(0xFFF59E0B),
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      Offset(rect.right - 111, rect.top + 40),
      maxWidth: 110,
      textAlign: TextAlign.right,
    );
    _paintText(
      canvas,
      '${course.reviewCount} 条评价',
      const TextStyle(
        color: Color(0xFF334155),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
      Offset(rect.right - 100, rect.top + 76),
      maxWidth: 98,
      textAlign: TextAlign.right,
    );
  }

  void _paintAvatar(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    if (avatar != null) {
      paintImage(canvas: canvas, rect: rect, image: avatar!, fit: BoxFit.cover);
    } else {
      final seed = (review.reviewerName?.trim().isNotEmpty ?? false)
          ? review.reviewerName!.trim()
          : '评论长图-${review.id}';
      canvas.translate(rect.left, rect.top);
      _paintBeamAvatar(canvas, rect.size, seed);
    }
    canvas.restore();
  }

  static void _paintBeamAvatar(Canvas canvas, Size size, String seed) {
    const colors = _BeamAvatarPainter._colors;
    final data = _BeamAvatarData(seed: seed, colors: colors);
    final scale = size.shortestSide / _BeamAvatarData.canvasSize;
    final dx = (size.width - size.shortestSide) / 2;
    final dy = (size.height - size.shortestSide) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    canvas.clipPath(
      Path()..addOval(
        const Rect.fromLTWH(
          0,
          0,
          _BeamAvatarData.canvasSize,
          _BeamAvatarData.canvasSize,
        ),
      ),
    );
    canvas.drawRect(
      const Rect.fromLTWH(
        0,
        0,
        _BeamAvatarData.canvasSize,
        _BeamAvatarData.canvasSize,
      ),
      Paint()..color = data.backgroundColor,
    );
    canvas.save();
    canvas.translate(data.wrapperTranslateX, data.wrapperTranslateY);
    canvas.translate(18, 18);
    canvas.rotate(data.wrapperRotate * math.pi / 180);
    canvas.translate(-18, -18);
    canvas.scale(data.wrapperScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(
          0,
          0,
          _BeamAvatarData.canvasSize,
          _BeamAvatarData.canvasSize,
        ),
        Radius.circular(data.isCircle ? _BeamAvatarData.canvasSize : 6),
      ),
      Paint()..color = data.wrapperColor,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(data.faceTranslateX, data.faceTranslateY);
    canvas.translate(18, 18);
    canvas.rotate(data.faceRotate * math.pi / 180);
    canvas.translate(-18, -18);
    final facePaint = Paint()..color = data.faceColor;
    final mouthY = 19.0 + data.mouthSpread;
    if (data.isMouthOpen) {
      final path = Path()
        ..moveTo(15, mouthY)
        ..cubicTo(17, mouthY + 1, 19, mouthY + 1, 21, mouthY);
      canvas.drawPath(
        path,
        Paint()
          ..color = data.faceColor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(13, mouthY - 0.75, 10, 1.5),
        0,
        math.pi,
        false,
        facePaint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 - data.eyeSpread, 14, 1.5, 2),
        const Radius.circular(1),
      ),
      facePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20 + data.eyeSpread, 14, 1.5, 2),
        const Radius.circular(1),
      ),
      facePaint,
    );
    canvas.restore();
    canvas.restore();
  }

  static Size _measurePills(List<String> labels, double maxWidth) {
    var x = 0.0;
    var height = 31.0;
    var rows = 1;
    for (final label in labels) {
      final size = _measureText(
        label,
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        maxWidth: maxWidth,
      );
      final pillWidth = math.min(size.width + 26, maxWidth);
      if (x > 0 && x + pillWidth > maxWidth) {
        rows++;
        x = 0;
      }
      x += pillWidth + 10;
    }
    height = rows * 31 + (rows - 1) * 10;
    return Size(maxWidth, height);
  }

  static double _measureMarkdownBlocks(
    List<_ShareMarkdownBlock> blocks, {
    required double maxWidth,
  }) {
    var height = 0.0;
    for (final block in blocks) {
      height += _markdownBlockHeight(block, maxWidth);
    }
    return math.max(28, height);
  }

  static double _paintMarkdownBlocks(
    Canvas canvas,
    List<_ShareMarkdownBlock> blocks,
    Offset offset, {
    required double maxWidth,
  }) {
    var y = offset.dy;
    for (final block in blocks) {
      y += _paintMarkdownBlock(canvas, block, Offset(offset.dx, y), maxWidth);
    }
    return y - offset.dy;
  }

  static double _markdownBlockHeight(
    _ShareMarkdownBlock block,
    double maxWidth,
  ) {
    final style = _markdownTextStyle(block);
    final leftInset = _markdownLeftInset(block);
    final textWidth = math.max(20.0, maxWidth - leftInset);
    if (block.type == _ShareMarkdownBlockType.divider) return 18;
    final painter = _layoutText(
      _markdownDisplayText(block),
      style,
      maxWidth: textWidth,
    );
    return painter.height + _markdownBottomSpacing(block);
  }

  static double _paintMarkdownBlock(
    Canvas canvas,
    _ShareMarkdownBlock block,
    Offset offset,
    double maxWidth,
  ) {
    if (block.type == _ShareMarkdownBlockType.divider) {
      canvas.drawLine(
        Offset(offset.dx, offset.dy + 8),
        Offset(offset.dx + maxWidth, offset.dy + 8),
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1,
      );
      return 18;
    }

    final leftInset = _markdownLeftInset(block);
    final style = _markdownTextStyle(block);
    final text = _markdownDisplayText(block);
    final textWidth = math.max(20.0, maxWidth - leftInset);
    final painter = _layoutText(text, style, maxWidth: textWidth);
    final textOffset = Offset(offset.dx + leftInset, offset.dy);

    if (block.type == _ShareMarkdownBlockType.quote) {
      final rect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        maxWidth,
        painter.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        Paint()..color = const Color(0xFFF8FAFC),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(offset.dx, offset.dy, 4, painter.height + 8),
          const Radius.circular(999),
        ),
        Paint()..color = const Color(0xFFCBD5E1),
      );
      painter.paint(canvas, Offset(textOffset.dx, textOffset.dy + 4));
    } else if (block.type == _ShareMarkdownBlockType.code) {
      final rect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        maxWidth,
        painter.height + 18,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()..color = const Color(0xFF0F172A),
      );
      painter.paint(canvas, Offset(textOffset.dx + 12, textOffset.dy + 9));
    } else {
      if (block.type == _ShareMarkdownBlockType.bullet) {
        canvas.drawCircle(
          Offset(offset.dx + 5, offset.dy + 11),
          3,
          Paint()..color = const Color(0xFF38BDF8),
        );
      }
      painter.paint(canvas, textOffset);
    }

    return _markdownBlockHeight(block, maxWidth);
  }

  static double _markdownLeftInset(_ShareMarkdownBlock block) {
    return switch (block.type) {
      _ShareMarkdownBlockType.bullet => 18,
      _ShareMarkdownBlockType.quote => 16,
      _ShareMarkdownBlockType.code => 0,
      _ => 0,
    };
  }

  static double _markdownBottomSpacing(_ShareMarkdownBlock block) {
    return switch (block.type) {
      _ShareMarkdownBlockType.heading => 10,
      _ShareMarkdownBlockType.bullet => 4,
      _ShareMarkdownBlockType.quote => 10,
      _ShareMarkdownBlockType.code => 16,
      _ShareMarkdownBlockType.paragraph => 10,
      _ShareMarkdownBlockType.divider => 0,
    };
  }

  static TextStyle _markdownTextStyle(_ShareMarkdownBlock block) {
    return switch (block.type) {
      _ShareMarkdownBlockType.heading => const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 19,
        height: 1.36,
        fontWeight: FontWeight.w900,
      ),
      _ShareMarkdownBlockType.bullet => const TextStyle(
        color: Color(0xFF334155),
        fontSize: 16,
        height: 1.62,
        fontWeight: FontWeight.w500,
      ),
      _ShareMarkdownBlockType.quote => const TextStyle(
        color: Color(0xFF475569),
        fontSize: 15,
        height: 1.58,
        fontWeight: FontWeight.w600,
      ),
      _ShareMarkdownBlockType.code => const TextStyle(
        color: Color(0xFFE2E8F0),
        fontSize: 13,
        height: 1.55,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
      ),
      _ => const TextStyle(
        color: Color(0xFF334155),
        fontSize: 16,
        height: 1.72,
        fontWeight: FontWeight.w500,
      ),
    };
  }

  static String _markdownDisplayText(_ShareMarkdownBlock block) {
    return block.text.trim();
  }

  static double _paintPillWrap(
    Canvas canvas,
    List<_ShareImagePill> pills,
    Offset offset, {
    required double maxWidth,
  }) {
    var x = offset.dx;
    var y = offset.dy;
    for (final pill in pills) {
      final size = _measureText(
        pill.text,
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        maxWidth: maxWidth,
      );
      final pillWidth = math.min(size.width + 26, maxWidth);
      if (x > offset.dx && x + pillWidth > offset.dx + maxWidth) {
        x = offset.dx;
        y += 41;
      }
      _paintPill(
        canvas,
        pill.text,
        Offset(x, y),
        foreground: pill.foreground,
        background: pill.background,
        maxWidth: pillWidth - 26,
      );
      x += pillWidth + 10;
    }
    return y + 31;
  }

  static void _paintPill(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color foreground,
    required Color background,
    double maxWidth = 280,
  }) {
    final painter = _layoutText(
      text,
      TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w900),
      maxWidth: maxWidth,
      maxLines: 1,
    );
    final rect = Rect.fromLTWH(offset.dx, offset.dy, painter.width + 26, 31);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      Paint()..color = background,
    );
    painter.paint(canvas, Offset(offset.dx + 13, offset.dy + 7));
  }

  static void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset offset, {
    required double maxWidth,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = _layoutText(
      text,
      style,
      maxWidth: maxWidth,
      maxLines: maxLines,
      textAlign: textAlign,
    );
    painter.paint(canvas, offset);
  }

  static Size _measureText(
    String text,
    TextStyle style, {
    required double maxWidth,
    int? maxLines,
  }) {
    final painter = _layoutText(
      text,
      style,
      maxWidth: maxWidth,
      maxLines: maxLines,
    );
    return painter.size;
  }

  static TextPainter _layoutText(
    String text,
    TextStyle style, {
    required double maxWidth,
    int? maxLines,
    TextAlign textAlign = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter;
  }
}

class _ShareImagePill {
  const _ShareImagePill({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;
}

enum _ShareMarkdownBlockType {
  paragraph,
  heading,
  bullet,
  quote,
  code,
  divider,
}

class _ShareMarkdownBlock {
  const _ShareMarkdownBlock({required this.type, required this.text});

  final _ShareMarkdownBlockType type;
  final String text;
}

List<_ShareMarkdownBlock> _parseShareMarkdown(String source) {
  final normalized = normalizeReviewMarkdown(source).trim();
  if (normalized.isEmpty) {
    return const [
      _ShareMarkdownBlock(type: _ShareMarkdownBlockType.paragraph, text: ' '),
    ];
  }

  final document = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final blocks = document
      .parse(normalized)
      .expand(_shareMarkdownBlocksFromNode)
      .toList(growable: false);
  return blocks.isEmpty
      ? const [
          _ShareMarkdownBlock(
            type: _ShareMarkdownBlockType.paragraph,
            text: ' ',
          ),
        ]
      : blocks;
}

Iterable<_ShareMarkdownBlock> _shareMarkdownBlocksFromNode(md.Node node) {
  if (node is! md.Element) {
    final text = _shareMarkdownText(node).trim();
    return text.isEmpty
        ? const []
        : [
            _ShareMarkdownBlock(
              type: _ShareMarkdownBlockType.paragraph,
              text: text,
            ),
          ];
  }

  switch (node.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      return _singleShareMarkdownBlock(node, _ShareMarkdownBlockType.heading);
    case 'p':
      return _singleShareMarkdownBlock(node, _ShareMarkdownBlockType.paragraph);
    case 'blockquote':
      return _singleShareMarkdownBlock(node, _ShareMarkdownBlockType.quote);
    case 'pre':
      return _singleShareMarkdownBlock(node, _ShareMarkdownBlockType.code);
    case 'hr':
      return const [
        _ShareMarkdownBlock(type: _ShareMarkdownBlockType.divider, text: ''),
      ];
    case 'ul':
    case 'ol':
      return _shareMarkdownListBlocks(node);
    case 'table':
      return _shareMarkdownTableBlocks(node);
    default:
      final children = node.children;
      if (children == null || children.isEmpty) {
        final text = _shareMarkdownText(node).trim();
        return text.isEmpty
            ? const []
            : [
                _ShareMarkdownBlock(
                  type: _ShareMarkdownBlockType.paragraph,
                  text: text,
                ),
              ];
      }
      return children.expand(_shareMarkdownBlocksFromNode);
  }
}

Iterable<_ShareMarkdownBlock> _singleShareMarkdownBlock(
  md.Node node,
  _ShareMarkdownBlockType type,
) {
  final text = _shareMarkdownText(node).trim();
  return text.isEmpty
      ? const []
      : [_ShareMarkdownBlock(type: type, text: text)];
}

Iterable<_ShareMarkdownBlock> _shareMarkdownListBlocks(md.Element list) {
  final children = list.children ?? const <md.Node>[];
  return children
      .whereType<md.Element>()
      .where((item) => item.tag == 'li')
      .map((item) {
        final text = _shareMarkdownText(item).trim();
        return _ShareMarkdownBlock(
          type: _ShareMarkdownBlockType.bullet,
          text: text,
        );
      })
      .where((block) => block.text.isNotEmpty);
}

Iterable<_ShareMarkdownBlock> _shareMarkdownTableBlocks(md.Element table) {
  final rows = <String>[];
  void collectRows(md.Node node) {
    if (node is! md.Element) return;
    if (node.tag == 'tr') {
      final cells = (node.children ?? const <md.Node>[])
          .whereType<md.Element>()
          .where((cell) => cell.tag == 'th' || cell.tag == 'td')
          .map((cell) => _shareMarkdownText(cell).trim())
          .where((text) => text.isNotEmpty)
          .join(' / ');
      if (cells.isNotEmpty) rows.add(cells);
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      collectRows(child);
    }
  }

  collectRows(table);
  return rows.map(
    (row) =>
        _ShareMarkdownBlock(type: _ShareMarkdownBlockType.paragraph, text: row),
  );
}

String _shareMarkdownText(md.Node node) {
  if (node is md.Text) return node.text;
  if (node is! md.Element) return node.textContent;
  if (node.tag == 'br') return '\n';
  if (node.tag == 'img') return node.attributes['alt'] ?? '';
  final children = node.children;
  if (children == null || children.isEmpty) return node.textContent;
  final buffer = StringBuffer();
  for (final child in children) {
    final text = _shareMarkdownText(child);
    if (text.isEmpty) continue;
    buffer.write(text);
  }
  return buffer.toString();
}

Future<void> showReviewShareDialog(
  BuildContext context, {
  required CourseDetail course,
  required Review review,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _ReviewShareDialog(course: course, review: review),
  );
}

class _ReviewShareDialog extends StatefulWidget {
  const _ReviewShareDialog({required this.course, required this.review});

  final CourseDetail course;
  final Review review;

  @override
  State<_ReviewShareDialog> createState() => _ReviewShareDialogState();
}

class _ReviewShareDialogState extends State<_ReviewShareDialog> {
  static const _platform = MethodChannel('de.yourtj.course.flutter/updater');

  Uint8List? _pngBytes;
  String? _message;
  var _saving = false;
  var _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generatePreview());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final png = _pngBytes;
    return AlertDialog(
      title: const Text('课程点评分享图'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 340,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (png == null)
              SizedBox(
                height: 420,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        '正在生成分享图',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 3,
                  child: Image.memory(png, fit: BoxFit.contain),
                ),
              ),
            if (_message != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_message!, style: theme.textTheme.bodySmall),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: png == null || _saving ? null : _saveToGallery,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt_outlined),
          label: Text(_saving ? '保存中...' : '保存到相册'),
        ),
        FilledButton.tonalIcon(
          onPressed: png == null || _sharing ? null : _shareImage,
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('分享'),
        ),
      ],
    );
  }

  Future<void> _generatePreview() async {
    try {
      final bytes = await renderReviewShareImage(widget.course, widget.review);
      if (!mounted) return;
      setState(() => _pngBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '分享图生成失败：$error');
    }
  }

  Future<void> _saveToGallery() async {
    final bytes = _pngBytes;
    if (bytes == null) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _platform.invokeMethod<String>('saveImageToGallery', {
        'bytes': bytes,
        'name': _shareFileName(widget.course, widget.review),
      });
      if (!mounted) return;
      setState(() => _message = '已保存到系统相册');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    final bytes = _pngBytes;
    if (bytes == null) return;
    setState(() {
      _sharing = true;
      _message = null;
    });
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${_shareFileName(widget.course, widget.review)}',
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '来自 YourTJ 选课社区的课程点评',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '分享失败：$error');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

Future<Uint8List> renderReviewShareImage(
  CourseDetail course,
  Review review, {
  double pixelRatio = 2.5,
}) async {
  final avatar = await _loadShareAvatarImage(review);
  final painter = _ReviewShareImagePainter(
    course: course,
    review: review,
    avatar: avatar,
  );
  final recorder = ui.PictureRecorder();
  final logicalSize = painter.measure();
  final canvas = Canvas(
    recorder,
    Offset.zero &
        Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio),
  )..scale(pixelRatio);
  painter.paint(canvas, logicalSize);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (logicalSize.width * pixelRatio).ceil(),
    (logicalSize.height * pixelRatio).ceil(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  avatar?.dispose();
  final data = bytes?.buffer.asUint8List();
  if (data == null) throw StateError('分享图生成失败');
  return data;
}

String _shareFileName(CourseDetail course, Review review) {
  final safeCode = (course.code.isEmpty ? 'yourtj' : course.code).replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  final safeId = review.sqid.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '$safeCode-$safeId.png';
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
