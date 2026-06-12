import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/models/runtime_state.dart';
import '../../domain/repositories/settings_repository.dart';

/// Polling interval for runtime state (15 seconds).
const _kPollInterval = Duration(seconds: 15);

/// Provider for the global runtime state (maintenance + announcements).
final runtimeStateProvider = StateNotifierProvider<RuntimeStateController, AsyncValue<RuntimeState?>>(
  (ref) => RuntimeStateController(ref),
);

class RuntimeStateController extends StateNotifier<AsyncValue<RuntimeState?>> {
  RuntimeStateController(this._ref) : super(const AsyncData(null)) {
    _poll();
    _startLifecycleListener();
  }

  final Ref _ref;
  Timer? _timer;
  late final AppLifecycleListener _lifecycleListener;

  void _startLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Refresh immediately when app comes to foreground.
        _fetch();
      },
    );
  }

  void _poll() {
    _fetch();
    _timer = Timer.periodic(_kPollInterval, (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final repo = _ref.read(settingsRepositoryProvider);
      final result = await repo.getRuntimeState(
        // Add timestamp to bust caches.
        extraHeaders: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      state = AsyncData(result);
    } catch (e, stack) {
      // Don't override existing data on error — keep showing last known state.
      if (state.value == null) {
        state = AsyncError(e, stack);
      }
    }
  }

  /// Manual refresh, e.g. after login.
  void refresh() => _fetch();

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }
}
