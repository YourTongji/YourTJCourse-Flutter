import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/runtime_state.dart';
import '../../domain/repositories/settings_repository.dart';

const _announcementPollInterval = Duration(minutes: 5);

final announcementControllerProvider =
    AsyncNotifierProvider.autoDispose<AnnouncementController, Announcement?>(
      AnnouncementController.new,
    );

class AnnouncementController extends AsyncNotifier<Announcement?> {
  static const _lastReadKey = 'de.yourtj.course.lastReadAnnouncementId';
  Timer? _pollTimer;

  @override
  Future<Announcement?> build() async {
    final result = await _fetchLatest();
    _startPolling();
    ref.onDispose(() => _pollTimer?.cancel());
    return result;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_announcementPollInterval, (_) {
      ref.invalidateSelf();
    });
  }

  Future<Announcement?> _fetchLatest() async {
    final runtimeState = await ref
        .watch(settingsRepositoryProvider)
        .getRuntimeState();
    final announcements = runtimeState.announcements
        .where((item) => item.id.isNotEmpty && item.content.isNotEmpty)
        .toList(growable: false);
    if (announcements.isEmpty) return null;

    final latest = announcements.first;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_lastReadKey) == latest.id) return null;
    return latest;
  }

  Future<void> markRead(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastReadKey, id);
    state = const AsyncData(null);
  }
}
