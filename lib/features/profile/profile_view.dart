import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/local_review_store.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/rating_stars.dart';
import '../course_detail/course_detail_controller.dart';
import '../course_detail/course_detail_view.dart';

final profileReviewsProvider = FutureProvider.autoDispose<ProfileReviewsState>((
  ref,
) async {
  final store = ref.watch(localReviewStoreProvider);
  final results = await Future.wait([
    store.loadMine(),
    store.loadFavorites(),
    store.loadHidden(),
  ]);
  return ProfileReviewsState(
    mine: results[0],
    favorites: results[1],
    hidden: results[2],
  );
});

class ProfileReviewsState {
  const ProfileReviewsState({
    required this.mine,
    required this.favorites,
    required this.hidden,
  });

  final List<LocalReviewEntry> mine;
  final List<LocalReviewEntry> favorites;
  final List<LocalReviewEntry> hidden;
}

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  var _segment = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileReviewsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: state.when(
        loading: () => const LoadingState(message: '正在读取本机点评'),
        error: (error, _) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(profileReviewsProvider),
        ),
        data: (data) {
          final entries = switch (_segment) {
            0 => data.mine,
            1 => data.favorites,
            _ => data.hidden,
          };
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(profileReviewsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipOval(child: Image.asset('assets/images/app_logo.png', width: 52)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YourTJ Course',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '钱包、积分与身份能力开发中',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('我的'),
                      icon: Icon(Icons.rate_review_outlined),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('收藏'),
                      icon: Icon(Icons.bookmark_border),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text('隐藏'),
                      icon: Icon(Icons.visibility_off_outlined),
                    ),
                  ],
                  selected: {_segment},
                  onSelectionChanged: (value) {
                    setState(() => _segment = value.single);
                  },
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  SizedBox(
                    height: 260,
                    child: EmptyState(message: _emptyMessage),
                  )
                else
                  for (final entry in entries)
                    _ProfileReviewTile(
                      entry: entry,
                      mode: _segment,
                      onRefresh: () => ref.invalidate(profileReviewsProvider),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  String get _emptyMessage {
    return switch (_segment) {
      0 => '还没有在本机写过点评',
      1 => '还没有收藏点评',
      _ => '还没有隐藏点评',
    };
  }
}

class _ProfileReviewTile extends ConsumerWidget {
  const _ProfileReviewTile({
    required this.entry,
    required this.mode,
    required this.onRefresh,
  });

  final LocalReviewEntry entry;
  final int mode;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReviewAvatar(review: entry.review, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${entry.courseCode} · ${entry.teacherName.isEmpty ? '未知教师' : entry.teacherName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                RatingStars(rating: entry.review.rating.toDouble(), size: 14),
                const SizedBox(width: 8),
                Text(
                  '${entry.review.rating.toStringAsFixed(1)} 分 · ${entry.review.semester}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.review.comment,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => context.push('/course/${entry.courseId}'),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('打开课程'),
                ),
                if (mode == 0)
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('再次编辑能力开发中')),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('再次编辑'),
                  ),
                if (mode == 1)
                  TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(localReviewStoreProvider)
                          .removeFavorite(entry.review.id);
                      onRefresh();
                    },
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    label: const Text('取消收藏'),
                  ),
                if (mode == 2)
                  TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(localReviewStoreProvider)
                          .removeHidden(entry.review.id);
                      await const HiddenReviewStore().save(
                        (await const HiddenReviewStore().load())
                          ..remove(entry.review.id),
                      );
                      onRefresh();
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('恢复'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
