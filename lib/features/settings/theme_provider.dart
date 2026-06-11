import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// YTJ preset seed colors for multi-theme support.
const ytjPresetColors = <Color>[
  Color(0xFF036099), // YTJ brand blue
  Color(0xFF6C63FF), // purple
  Color(0xFF2E7D32), // green
  Color(0xFFE65100), // orange
  Color(0xFFAD1457), // pink
  Color(0xFF00695C), // teal
  Color(0xFFC62828), // red
  Color(0xFF283593), // indigo
  Color(0xFFF9A825), // amber
  Color(0xFF00838F), // cyan
];

/// Theme mode + seed color state, persisted via SharedPreferences.
class ThemeState {
  const ThemeState({
    this.mode = ThemeMode.system,
    this.seedColor = _kDefaultSeed,
  });

  final ThemeMode mode;
  final Color seedColor;

  static const _kDefaultSeed = Color(0xFF036099);

  ThemeState copyWith({ThemeMode? mode, Color? seedColor}) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'seedColor': seedColor.toARGB32(),
  };
}

final themeStateProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);

class ThemeNotifier extends AsyncNotifier<ThemeState> {
  @override
  Future<ThemeState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode');
    final seedVal = prefs.getInt('theme_seed');
    return ThemeState(
      mode: _parseMode(modeStr),
      seedColor: seedVal != null ? Color(seedVal) : ThemeState._kDefaultSeed,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(state.requireValue.copyWith(mode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> setSeedColor(Color color) async {
    state = AsyncData(state.requireValue.copyWith(seedColor: color));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_seed', color.toARGB32());
  }

  static ThemeMode _parseMode(String? s) {
    return switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
