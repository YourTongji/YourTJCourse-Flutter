import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

import '../../domain/models/review.dart';
import '../../domain/repositories/local_review_store.dart';
import '../../domain/repositories/review_repository.dart';
import '../../shared/markdown/review_markdown.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/wallet_card.dart';
import '../course_detail/course_detail_controller.dart';
import '../course_detail/course_detail_view.dart';
import '../../shared/widgets/pending_edit_provider.dart';
import '../wallet/wallet_controller.dart';

/// Fetch reviews from server by wallet hash, then merge with local ones.
/// NOT autoDispose: must stay alive and re-evaluate when walletProvider changes
/// so that reviews with wallet_user_hash are correctly detected as editable.
final _walletReviewsProvider = FutureProvider<List<LocalReviewEntry>>(
  (ref) async {
    final wallet = ref.watch(walletProvider);
    final userHash = wallet.value?.userHash;
    if (userHash == null || userHash.isEmpty) return [];
    try {
      final reviews = await ref.read(reviewRepositoryProvider).fetchWalletReviews(userHash);
      return reviews;
    } catch (_) {
      return [];
    }
  },
);

final profileReviewsProvider = FutureProvider.autoDispose<ProfileReviewsState>((
  ref,
) async {
  final store = ref.watch(localReviewStoreProvider);

  // Load local and server reviews concurrently.
  final results = await Future.wait([
    store.loadMine(),
    store.loadFavorites(),
    store.loadHidden(),
    ref.watch(_walletReviewsProvider.future),
  ]);

  final localMine = results[0];
  final favorites = results[1];
  final hidden = results[2];
  final serverMine = results[3];

  // Merge: server reviews take precedence; append local-only entries.
  final serverIds = serverMine.map((e) => e.review.id).toSet();
  final merged = [...serverMine];
  for (final local in localMine) {
    if (!serverIds.contains(local.review.id)) {
      merged.add(local);
    }
  }
  // Sort all reviews by created_at descending (newest first).
  // Parse both ISO 8601 and SQLite formats as DateTime for correct ordering.
  merged.sort((a, b) {
    final da = DateTime.tryParse(a.review.createdAt) ?? DateTime(0);
    final db = DateTime.tryParse(b.review.createdAt) ?? DateTime(0);
    return db.compareTo(da);
  });

  return ProfileReviewsState(
    mine: merged,
    favorites: favorites,
    hidden: hidden,
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
                // Wallet card — compact mode
                _buildWalletCardSection(ref, theme),
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

  /// Wallet card section in the profile.
  Widget _buildWalletCardSection(WidgetRef ref, ThemeData theme) {
    final wallet = ref.watch(walletProvider);

    return wallet.when(
      loading: () => WalletCard(
        balance: 0,
        mode: WalletCardMode.compact,
        isLoading: true,
        label: '积分',
        onTap: () => context.push('/wallet'),
      ),
      error: (_, _) => WalletCard(
        balance: 0,
        mode: WalletCardMode.compact,
        isError: true,
        onRefresh: () => ref.invalidate(walletProvider),
        onTap: () => context.push('/wallet'),
      ),
      data: (state) {
        if (!state.hasWallet) {
          return WalletCard(
            balance: 0,
            mode: WalletCardMode.compact,
            isError: false,
            label: '未注册钱包',
            onTap: () => context.push('/wallet'),
          );
        }
        return WalletCard(
          balance: state.balance,
          mode: WalletCardMode.compact,
          onTap: () => context.push('/wallet'),
          onRefresh: () => ref.invalidate(walletProvider),
        );
      },
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: ClipRect(
                child: MarkdownBody(
                  data: normalizeReviewMarkdown(entry.review.comment),
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
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
                  _EditReviewButton(
                    courseId: entry.courseId,
                    review: entry.review,
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

/// Shows "再次编辑" with context-appropriate hints.
class _EditReviewButton extends ConsumerWidget {
  const _EditReviewButton({required this.courseId, required this.review});

  final int courseId;
  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final hasWallet = wallet.value?.hasWallet ?? false;

    // Check if this review exists on the server with wallet binding.
    final serverReviews = ref.watch(_walletReviewsProvider);
    final isOnServer = serverReviews.value?.any((e) => e.review.id == review.id) ?? false;

    return TextButton.icon(
      onPressed: () {
        if (!hasWallet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('再次编辑需要绑定积分钱包')),
          );
          return;
        }
        if (!isOnServer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂不支持仅本机评论编辑')),
          );
          return;
        }
        ref.read(pendingEditProvider.notifier).set(courseId, review);
        context.push('/course/$courseId');
      },
      icon: const Icon(Icons.edit_outlined),
      label: const Text('再次编辑'),
    );
  }
}
