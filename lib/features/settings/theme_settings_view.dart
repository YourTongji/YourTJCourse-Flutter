import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

/// 外观设置页。
class ThemeSettingsView extends ConsumerWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('外观设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── 主题模式 ─────────────────────────────────────────────
          _SectionHeader(title: '主题模式', icon: Icons.brightness_6_outlined),
          const SizedBox(height: 12),
          _ThemeModeSection(themeState: themeState),
          const SizedBox(height: 24),

          // ── 主题色 ────────────────────────────────────────────────
          _SectionHeader(title: '主题色', icon: Icons.color_lens_outlined),
          const SizedBox(height: 12),
          const _ThemeColorSection(),
          const SizedBox(height: 24),

          // ── 色调变体（配色风格） ──────────────────────────────────
          _SectionHeader(title: '配色风格', icon: Icons.color_lens_outlined),
          const SizedBox(height: 12),
          const _SchemeVariantSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Section header
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Theme mode: 3 cards with mini screen previews
// ═══════════════════════════════════════════════════════════════════

class _ThemeModeSection extends ConsumerWidget {
  final ThemeState themeState;
  const _ThemeModeSection({required this.themeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final effectiveSeed = themeState.useDynamicColor ? cs.primary : themeState.seedColor;
    final variant = themeState.schemeVariant;

    final lightScheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      brightness: Brightness.light,
      dynamicSchemeVariant: variant,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: variant,
    );

    final notifier = ref.read(themeProvider.notifier);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.auto_mode,
                label: '跟随系统',
                lightScheme: lightScheme,
                darkScheme: darkScheme,
                isSelected: themeState.mode == ThemeMode.system,
                cs: cs,
                onTap: () => notifier.setThemeMode(ThemeMode.system),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                icon: Icons.light_mode,
                label: '浅色',
                scheme: lightScheme,
                lightScheme: lightScheme,
                darkScheme: darkScheme,
                isSelected: themeState.mode == ThemeMode.light,
                cs: cs,
                onTap: () => notifier.setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                icon: Icons.dark_mode,
                label: '深色',
                scheme: darkScheme,
                lightScheme: lightScheme,
                darkScheme: darkScheme,
                isSelected: themeState.mode == ThemeMode.dark,
                cs: cs,
                onTap: () => notifier.setThemeMode(ThemeMode.dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme? scheme;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final bool isSelected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    this.scheme,
    required this.lightScheme,
    required this.darkScheme,
    required this.isSelected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.secondaryContainer.withValues(alpha: 0.5)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Mini screen preview
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 56,
                  child: scheme == null
                      ? _MiniSplitScreen(
                          lightScheme: lightScheme,
                          darkScheme: darkScheme,
                        )
                      : _MiniScreen(scheme: scheme!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single mode mini screen preview.
class _MiniScreen extends StatelessWidget {
  final ColorScheme scheme;
  const _MiniScreen({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(children: [
              const SizedBox(width: 3),
              Container(
                width: 16, height: 5,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 3),
          _contentLine(scheme, 0.7),
          const SizedBox(height: 2),
          _contentLine(scheme, 0.5),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 14, height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _contentLine(ColorScheme scheme, double wf) {
    return FractionallySizedBox(
      widthFactor: wf,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Split screen for "system" mode.
class _MiniSplitScreen extends StatelessWidget {
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  const _MiniSplitScreen({required this.lightScheme, required this.darkScheme});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplitThemePreviewPainter(
        lightScheme: lightScheme,
        darkScheme: darkScheme,
      ),
      size: const Size(double.infinity, 56),
    );
  }
}

class _SplitThemePreviewPainter extends CustomPainter {
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  _SplitThemePreviewPainter({required this.lightScheme, required this.darkScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;
    final paint = Paint();
    const pad = 4.0;

    paint.color = lightScheme.surface;
    canvas.drawRect(Rect.fromLTRB(0, 0, midX, size.height), paint);
    paint.color = darkScheme.surface;
    canvas.drawRect(Rect.fromLTRB(midX, 0, size.width, size.height), paint);

    _drawSplitRRect(canvas, size, Rect.fromLTWH(pad, pad, size.width - pad * 2, 10), 3,
        lightScheme.surfaceContainerHighest, darkScheme.surfaceContainerHighest);
    _drawSplitRRect(canvas, size, Rect.fromLTWH(pad + 3, pad + 2.5, 16, 5), 2,
        lightScheme.onSurface.withValues(alpha:0.6), darkScheme.onSurface.withValues(alpha:0.6));

    final y1 = pad + 13.0;
    _drawSplitRRect(canvas, size, Rect.fromLTWH(pad, y1, (size.width - pad * 2) * 0.7, 4), 2,
        lightScheme.onSurface.withValues(alpha:0.15), darkScheme.onSurface.withValues(alpha:0.15));
    final y2 = y1 + 6;
    _drawSplitRRect(canvas, size, Rect.fromLTWH(pad, y2, (size.width - pad * 2) * 0.5, 4), 2,
        lightScheme.onSurface.withValues(alpha:0.15), darkScheme.onSurface.withValues(alpha:0.15));

    const btnW = 14.0, btnH = 6.0;
    _drawSplitRRect(canvas, size,
        Rect.fromLTWH(size.width - pad - btnW, y2 + 8, btnW, btnH), 3,
        lightScheme.primary, darkScheme.primary);

    paint.color = lightScheme.outline.withValues(alpha:0.1);
    paint.strokeWidth = 0.5;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
  }

  void _drawSplitRRect(Canvas canvas, Size size, Rect rect, double r, Color lc, Color dc) {
    final midX = size.width / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final paint = Paint();
    canvas.save(); canvas.clipRect(Rect.fromLTRB(0, 0, midX, size.height));
    paint.color = lc; canvas.drawRRect(rrect, paint); canvas.restore();
    canvas.save(); canvas.clipRect(Rect.fromLTRB(midX, 0, size.width, size.height));
    paint.color = dc; canvas.drawRRect(rrect, paint); canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplitThemePreviewPainter old) =>
      old.lightScheme != lightScheme || old.darkScheme != darkScheme;
}

// ═══════════════════════════════════════════════════════════════════
// Theme color: swatch grid (dynamic + presets + custom + add)
// ═══════════════════════════════════════════════════════════════════

class _ThemeColorSection extends ConsumerWidget {
  const _ThemeColorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDynamic = themeState.useDynamicColor;
    final currentColor = themeState.seedColor;
    final variant = themeState.schemeVariant;
    final customColors = themeState.customColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = (maxWidth / 88).floor().clamp(3, 6);
        const spacing = 14.0;
        final itemWidth = (maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            // Dynamic color
            _ColorSwatchCard(
              size: itemWidth,
              isSelected: isDynamic,
              isDynamic: true,
              variant: variant,
              seedColor: currentColor,
              onTap: () => ref.read(themeProvider.notifier).setUseDynamicColor(true),
            ),
            // Preset colors
            for (final color in ytjPresetColors)
              _ColorSwatchCard(
                size: itemWidth,
                seedColor: color,
                isSelected: !isDynamic && color.toARGB32() == currentColor.toARGB32(),
                variant: variant,
                onTap: () => ref.read(themeProvider.notifier).setSeedColor(color),
              ),
            // Custom colors
            for (final color in customColors)
              _ColorSwatchCard(
                size: itemWidth,
                seedColor: color,
                isSelected: !isDynamic && color.toARGB32() == currentColor.toARGB32(),
                variant: variant,
                onTap: () => ref.read(themeProvider.notifier).setSeedColor(color),
              ),
            // Add button
            SizedBox(
              width: itemWidth,
              height: itemWidth,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton.filledTonal(
                  onPressed: () => _showColorPicker(context, ref),
                  iconSize: 28,
                  icon: Icon(Icons.add, color: cs.primary),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final currentColor = ref.read(themeProvider).seedColor;
    var hue = HSVColor.fromColor(currentColor).hue;
    var saturation = HSVColor.fromColor(currentColor).saturation;
    var value = HSVColor.fromColor(currentColor).value;

    showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final color = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
            final previewScheme = ColorScheme.fromSeed(
              seedColor: color,
              dynamicSchemeVariant: ref.read(themeProvider).schemeVariant,
              brightness: Theme.of(context).brightness,
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color preview
                    Row(children: [
                      Container(
                        width: 60, height: 60,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: previewScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: previewScheme.primary, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 7, child: ColoredBox(color: previewScheme.primary)),
                            Expanded(flex: 3, child: Center(child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _colorDot(previewScheme.primary, 8),
                                const SizedBox(width: 5),
                                _colorDot(previewScheme.secondary, 8),
                                const SizedBox(width: 5),
                                _colorDot(previewScheme.tertiary, 8),
                              ],
                            ))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500, fontFamily: 'monospace')),
                          const SizedBox(height: 4),
                          Text('H:${hue.round()}°  S:${(saturation * 100).round()}%  B:${(value * 100).round()}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 20),
                    _HueSlider(hue: hue, color: color, onChanged: (h) => setSheetState(() => hue = h)),
                    const SizedBox(height: 12),
                    _GradientSlider(label: 'S', value: saturation,
                        gradientColors: [HSVColor.fromAHSV(1, hue, 0, 1).toColor(), HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
                        thumbColor: HSVColor.fromAHSV(1, hue, saturation, 1).toColor(),
                        onChanged: (s) => setSheetState(() => saturation = s)),
                    const SizedBox(height: 8),
                    _GradientSlider(label: 'B', value: value,
                        gradientColors: [HSVColor.fromAHSV(1, hue, saturation, 0).toColor(), HSVColor.fromAHSV(1, hue, saturation, 1).toColor()],
                        thumbColor: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
                        onChanged: (v) => setSheetState(() => value = v)),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, color),
                      child: const Text('确认'),
                    )),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((color) {
      if (color != null) {
        ref.read(themeProvider.notifier).addCustomColor(color);
        ref.read(themeProvider.notifier).setSeedColor(color);
      }
    });
  }

  static Widget _colorDot(Color c, double d) {
    return Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

/// Color swatch card: primary fill + 3 color dots + check mark
class _ColorSwatchCard extends StatelessWidget {
  final double size;
  final Color? seedColor;
  final bool isSelected;
  final bool isDynamic;
  final DynamicSchemeVariant variant;
  final VoidCallback onTap;

  const _ColorSwatchCard({
    required this.size,
    this.seedColor,
    required this.isSelected,
    this.isDynamic = false,
    required this.variant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSeed = isDynamic
        ? Theme.of(context).colorScheme.primary
        : seedColor!;
    final tileScheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      dynamicSchemeVariant: variant,
      brightness: Theme.of(context).brightness,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tileScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tileScheme.primary : tileScheme.outlineVariant.withValues(alpha:0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Expanded(flex: 7, child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: tileScheme.primary),
            if (isSelected) Container(
              color: Colors.black.withValues(alpha:0.12),
              alignment: Alignment.center,
              child: Icon(Icons.check_circle_rounded, color: tileScheme.onPrimary, size: 26),
            ),
            if (isDynamic) Positioned(top: 5, right: 5,
              child: Icon(Icons.auto_awesome, size: 14,
                  color: tileScheme.onPrimary.withValues(alpha:0.85))),
          ])),
          Expanded(flex: 3, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(tileScheme.primary, 8), const SizedBox(width: 5),
            _dot(tileScheme.secondary, 8), const SizedBox(width: 5),
            _dot(tileScheme.tertiary, 8),
          ]))),
        ]),
      ),
    );
  }

  static Widget _dot(Color c, double d) =>
      Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ═══════════════════════════════════════════════════════════════════
// Scheme variant: horizontal scrollable chips
// ═══════════════════════════════════════════════════════════════════

class _SchemeVariantSection extends ConsumerWidget {
  const _SchemeVariantSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;
    final variant = themeState.schemeVariant;
    final effectiveSeed = themeState.useDynamicColor ? cs.primary : themeState.seedColor;

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DynamicSchemeVariant.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        padding: const EdgeInsets.only(right: 16),
        itemBuilder: (context, index) {
          final v = DynamicSchemeVariant.values[index];
          final scheme = ColorScheme.fromSeed(
            seedColor: effectiveSeed,
            dynamicSchemeVariant: v,
            brightness: Theme.of(context).brightness,
          );
          final isSelected = v == variant;

          return GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).setSchemeVariant(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? scheme.primary : cs.outlineVariant.withValues(alpha:0.3),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: ColoredBox(color: scheme.primary)),
                Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _dot(scheme.primary, 5), const SizedBox(width: 3),
                    _dot(scheme.secondary, 5), const SizedBox(width: 3),
                    _dot(scheme.tertiary, 5),
                  ])),
                Padding(padding: const EdgeInsets.only(bottom: 5, left: 4, right: 4),
                  child: Text(_variantLabel(v),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? scheme.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  static Widget _dot(Color c, double d) =>
      Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  String _variantLabel(DynamicSchemeVariant v) => switch (v) {
    DynamicSchemeVariant.tonalSpot => 'Tonal Spot',
    DynamicSchemeVariant.fidelity => 'Fidelity',
    DynamicSchemeVariant.monochrome => 'Monochrome',
    DynamicSchemeVariant.neutral => 'Neutral',
    DynamicSchemeVariant.vibrant => 'Vibrant',
    DynamicSchemeVariant.expressive => 'Expressive',
    DynamicSchemeVariant.content => 'Content',
    DynamicSchemeVariant.rainbow => 'Rainbow',
    DynamicSchemeVariant.fruitSalad => 'Fruit Salad',
  };
}

// ═══════════════════════════════════════════════════════════════════
// Hue bar slider
// ═══════════════════════════════════════════════════════════════════

class _HueSlider extends StatelessWidget {
  final double hue;
  final Color color;
  final ValueChanged<double> onChanged;

  const _HueSlider({required this.hue, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [
          Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
          Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
        ]),
      ),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 36,
          trackShape: const _TransparentTrackShape(),
          thumbShape: _ColorThumbShape(color: color),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        ),
        child: Slider(value: hue, min: 0, max: 360, onChanged: onChanged),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Gradient slider (S/B)
// ═══════════════════════════════════════════════════════════════════

class _GradientSlider extends StatelessWidget {
  final String label;
  final double value;
  final List<Color> gradientColors;
  final Color thumbColor;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.label, required this.value,
    required this.gradientColors, required this.thumbColor, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      SizedBox(width: 20, child: Text(label, style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant))),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 28,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: gradientColors)),
        child: SliderTheme(data: SliderTheme.of(context).copyWith(
          trackHeight: 28, trackShape: const _TransparentTrackShape(),
          thumbShape: _ColorThumbShape(color: thumbColor),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        ), child: Slider(value: value, onChanged: onChanged)),
      )),
      SizedBox(width: 44, child: Text('${(value * 100).round()}%',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.primary),
          textAlign: TextAlign.end)),
    ]);
  }
}

class _ColorThumbShape extends SliderComponentShape {
  final Color color;
  const _ColorThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(28, 28);

  @override
  void paint(PaintingContext context, Offset center, {
    required Animation<double> activationAnimation, required Animation<double> enableAnimation,
    required bool isDiscrete, required TextPainter labelPainter, required RenderBox parentBox,
    required SliderThemeData sliderTheme, required TextDirection textDirection,
    required double value, required double textScaleFactor, required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 14, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(center, 11, Paint()..color = color);
  }
}

class _TransparentTrackShape extends RoundedRectSliderTrackShape {
  const _TransparentTrackShape();
  @override
  void paint(PaintingContext context, Offset offset, {
    required RenderBox parentBox, required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation, required TextDirection textDirection,
    required Offset thumbCenter, Offset? secondaryOffset, bool isDiscrete = false,
    bool isEnabled = false, double additionalActiveTrackHeight = 0,
  }) {}
}
