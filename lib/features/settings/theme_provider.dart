import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// YTJ preset colors.
const ytjPresetColors = <Color>[
  Color(0xFF036099),
  Color(0xFF6C63FF),
  Color(0xFF2E7D32),
  Color(0xFFE65100),
  Color(0xFFAD1457),
  Color(0xFF00695C),
  Color(0xFFC62828),
  Color(0xFF283593),
  Color(0xFFF9A825),
  Color(0xFF00838F),
];

/// App Theme State.
class ThemeState {
  final ThemeMode mode;
  final Color seedColor;
  final bool useDynamicColor;
  final DynamicSchemeVariant schemeVariant;
  final List<Color> customColors;

  const ThemeState({
    this.mode = ThemeMode.system,
    this.seedColor = _kDefaultSeed,
    this.useDynamicColor = false,
    this.schemeVariant = DynamicSchemeVariant.tonalSpot,
    this.customColors = const [],
  });

  static const _kDefaultSeed = Color(0xFF036099);

  ThemeState copyWith({
    ThemeMode? mode,
    Color? seedColor,
    bool? useDynamicColor,
    DynamicSchemeVariant? schemeVariant,
    List<Color>? customColors,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      schemeVariant: schemeVariant ?? this.schemeVariant,
      customColors: customColors ?? this.customColors,
    );
  }
}

/// SharedPreferences instance provider.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override SharedPreferences in ProviderScope');
});

/// Theme provider — `StateNotifierProvider<ThemeNotifier, ThemeState>`.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeModeKey = 'ytj_theme_mode';
  static const String _seedColorKey = 'ytj_seed_color';
  static const String _dynamicColorKey = 'ytj_use_dynamic_color';
  static const String _schemeVariantKey = 'ytj_scheme_variant';
  static const String _customColorsKey = 'ytj_custom_colors';

  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) : super(_loadTheme(_prefs));

  static ThemeState _loadTheme(SharedPreferences prefs) {
    final savedMode = prefs.getString(_themeModeKey);
    ThemeMode mode = ThemeMode.system;
    if (savedMode == 'light') {
      mode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      mode = ThemeMode.dark;
    }

    final savedColorValue = prefs.getInt(_seedColorKey);
    Color seedColor = ThemeState._kDefaultSeed;
    if (savedColorValue != null) seedColor = Color(savedColorValue);

    final useDynamicColor = prefs.getBool(_dynamicColorKey) ?? false;

    final savedVariant = prefs.getString(_schemeVariantKey);
    DynamicSchemeVariant schemeVariant = DynamicSchemeVariant.tonalSpot;
    for (final v in DynamicSchemeVariant.values) {
      if (v.name == savedVariant) {
        schemeVariant = v;
        break;
      }
    }

    final savedCustomColors = prefs.getStringList(_customColorsKey) ?? [];
    final customColors = savedCustomColors
        .map((s) => int.tryParse(s))
        .where((v) => v != null)
        .map((v) => Color(v!))
        .toList();

    return ThemeState(
      mode: mode,
      seedColor: seedColor,
      useDynamicColor: useDynamicColor,
      schemeVariant: schemeVariant,
      customColors: customColors,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final value = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await _prefs.setString(_themeModeKey, value);
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color, useDynamicColor: false);
    await _prefs.setInt(_seedColorKey, color.toARGB32());
    await _prefs.setBool(_dynamicColorKey, false);
  }

  Future<void> setUseDynamicColor(bool value) async {
    state = state.copyWith(useDynamicColor: value);
    await _prefs.setBool(_dynamicColorKey, value);
  }

  Future<void> setSchemeVariant(DynamicSchemeVariant variant) async {
    state = state.copyWith(schemeVariant: variant);
    await _prefs.setString(_schemeVariantKey, variant.name);
  }

  Future<void> addCustomColor(Color color) async {
    final newColors = [...state.customColors, color];
    state = state.copyWith(customColors: newColors);
    await _saveCustomColors(newColors);
  }

  Future<void> removeCustomColor(Color color) async {
    final newColors = state.customColors
        .where((c) => c.toARGB32() != color.toARGB32())
        .toList();
    state = state.copyWith(customColors: newColors);
    if (state.seedColor.toARGB32() == color.toARGB32() && !state.useDynamicColor) {
      await setSeedColor(ThemeState._kDefaultSeed);
    }
    await _saveCustomColors(newColors);
  }

  Future<void> _saveCustomColors(List<Color> colors) async {
    await _prefs.setStringList(
      _customColorsKey,
      colors.map((c) => c.toARGB32().toString()).toList(),
    );
  }
}
