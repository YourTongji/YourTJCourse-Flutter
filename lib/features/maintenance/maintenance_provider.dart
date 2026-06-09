import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/runtime_state.dart';
import '../../domain/repositories/settings_repository.dart';

/// Polls the backend runtime state and exposes whether maintenance mode is active.
///
/// Matches iOS `StartupViewModel` behavior: fetches `/api/settings/runtime-state`
/// and checks `state.maintenance.enabled`. Additionally polls every 5 minutes
/// so the app responds to maintenance state changes while in use.
final maintenanceStateProvider =
    AsyncNotifierProvider.autoDispose<MaintenanceController, MaintenanceState>(
      MaintenanceController.new,
    );

class MaintenanceController extends AsyncNotifier<MaintenanceState> {
  Timer? _pollTimer;

  @override
  Future<MaintenanceState> build() async {
    // Fetch once, then poll periodically.
    final state = await _fetch();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.invalidateSelf();
    });
    ref.onDispose(() => _pollTimer?.cancel());
    return state;
  }

  Future<MaintenanceState> _fetch() async {
    try {
      final runtimeState = await ref
          .read(settingsRepositoryProvider)
          .getRuntimeState();
      return runtimeState.maintenance;
    } catch (_) {
      // Fetch failed (no network) — keep last known state or default disabled.
      return state.value ?? const MaintenanceState(enabled: false);
    }
  }

  /// Recheck maintenance state immediately (e.g., pull-to-refresh).
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
