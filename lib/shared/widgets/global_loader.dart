import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The YTJ brand glow blue used throughout the animated loader.
const _kGlowBlue = Color(0xFF51ddff);

// ─── Animated Cat Logo ─────────────────────────────────────────────

/// The blink-tail cat logo with Flutter-driven animations.
///
/// Extracted from `blink-tail.html` — the cat body is rendered via SVG,
/// while the tail sway and eye blink are driven by [AnimationController]
/// for precise control and composability.
class AnimatedCatLogo extends StatefulWidget {
  const AnimatedCatLogo({
    super.key,
    this.size = 200,
  });

  final double size;

  @override
  State<AnimatedCatLogo> createState() => _AnimatedCatLogoState();
}

class _AnimatedCatLogoState extends State<AnimatedCatLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // The cat body SVG (eyes visible by default).
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final tailRotation = _tailSway(_ctrl.value);
          final (eyeOpacity, eyeScale) = _blink(_ctrl.value);
          final (chevronOpacity, _) = _blinkChevrons(_ctrl.value);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Base cat body
              Positioned.fill(
                child: SvgPicture.asset(
                  'assets/images/logo-animated.svg',
                  fit: BoxFit.contain,
                ),
              ),

              // Tail overlay — rotate the tail portion
              Positioned(
                left: size * 0.66,
                top: size * 0.30,
                width: size * 0.35,
                height: size * 0.45,
                child: Transform.rotate(
                  angle: tailRotation,
                  child: SvgPicture.string(
                    _tailSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Eye blink — fade out open eyes, fade in closed lines
              // Left eye
              Positioned(
                left: size * 0.34,
                top: size * 0.305,
                width: size * 0.08,
                height: size * 0.06,
                child: Opacity(
                  opacity: eyeOpacity,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1.0, eyeScale, 1.0),
                    child: SvgPicture.string(
                      _leftEyeClosedSvg,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Right eye
              Positioned(
                left: size * 0.515,
                top: size * 0.30,
                width: size * 0.08,
                height: size * 0.06,
                child: Opacity(
                  opacity: eyeOpacity,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1.0, eyeScale, 1.0),
                    child: SvgPicture.string(
                      _rightEyeClosedSvg,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Chevron blink lines (appear when eyes close)
              Positioned(
                left: size * 0.33,
                top: size * 0.305,
                width: size * 0.10,
                height: size * 0.06,
                child: Opacity(
                  opacity: chevronOpacity,
                  child: SvgPicture.string(
                    _leftChevronSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: size * 0.505,
                top: size * 0.30,
                width: size * 0.10,
                height: size * 0.06,
                child: Opacity(
                  opacity: chevronOpacity,
                  child: SvgPicture.string(
                    _rightChevronSvg,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Animation math ─────────────────────────────────────────────

  double _tailSway(double t) {
    // Maps t[0,1) through the CSS keyframes:
    // 0%:-1.4°, 30%:3.2°, 58%:-3.6°, 78%:2°, 100%:-1.4°
    const keyframes = [
      (0.00, -1.4),
      (0.30, 3.2),
      (0.58, -3.6),
      (0.78, 2.0),
      (1.00, -1.4),
    ];
    for (var i = 0; i < keyframes.length - 1; i++) {
      final (t0, v0) = keyframes[i];
      final (t1, v1) = keyframes[i + 1];
      if (t >= t0 && t <= t1) {
        final p = (t - t0) / (t1 - t0);
        return lerpDouble(v0, v1, p)! * (math.pi / 180);
      }
    }
    return 0;
  }

  (double, double) _blink(double t) {
    // Map t through hide-open-eyes keyframe
    // 6%→opacity:1,scale:1 → 14%→opacity:0,scale:0.08 → 29%→opacity:0.55,scale:0.42 → 35%→1
    if (t < 0.05) return (1.0, 1.0);
    if (t < 0.10) {
      final p = (t - 0.05) / 0.05;
      return (1.0 - p * 0.55, 1.0 - p * 0.66);
    }
    if (t < 0.14) {
      final p = (t - 0.10) / 0.04;
      return (0.45 * (1 - p), 0.34 * (1 - p));
    }
    if (t < 0.22) return (0.0, 0.08);
    if (t < 0.29) {
      final p = (t - 0.22) / 0.07;
      return (p * 0.55, 0.08 + p * 0.34);
    }
    if (t < 0.35) {
      final p = (t - 0.29) / 0.06;
      return (0.55 + p * 0.45, 0.42 + p * 0.58);
    }
    return (1.0, 1.0);
  }

  (double, void) _blinkChevrons(double t) {
    // Opacity: 12%→0.86, 17%-24%→1, 29%→0.38
    if (t < 0.11) return (0.0, 0);
    if (t < 0.12) return ((t - 0.11) / 0.01 * 0.86, 0);
    if (t < 0.17) return (0.86, 0);
    if (t < 0.24) return (1.0, 0);
    if (t < 0.29) return (1.0 - (t - 0.24) / 0.05 * 0.62, 0);
    if (t < 0.32) return (0.38 - (t - 0.29) / 0.03 * 0.38, 0);
    return (0.0, 0);
  }
}

// ─── Inline SVG fragments for animated parts ───────────────────────

const _tailSvg = '''
<svg viewBox="0 0 400 400" xmlns="http://www.w3.org/2000/svg">
  <path d="m0,0c0,0 30,-60 80,-80c50,-20 120,-30 160,10c40,40 60,100 60,160c0,60 -20,100 -50,120c-30,20 -70,10 -100,-20c-30,-30 -50,-80 -50,-130c0,-50 20,-90 50,-110c30,-20 60,-10 80,20c20,30 30,70 20,100c-10,30 -30,40 -50,30c-20,-10 -30,-30 -20,-50c10,-20 30,-20 40,-10c10,10 10,30 0,40" fill="#046199"/>
</svg>
''';

const _leftEyeClosedSvg = '''
<svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
  <path d="M10,30 L50,45 L90,30" fill="none" stroke="#07629a" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _rightEyeClosedSvg = '''
<svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
  <path d="M10,30 L50,45 L90,30" fill="none" stroke="#066199" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _leftChevronSvg = '''
<svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
  <polyline points="20,50 50,25 80,50" fill="none" stroke="#07629a" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

const _rightChevronSvg = '''
<svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
  <polyline points="20,50 50,25 80,50" fill="none" stroke="#066199" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

// ─── Morphing Wave Circle ─────────────────────────────────────────

/// A Material 3 expressive morphing loading indicator.
///
/// Draws a circular ring with a flowing wave pattern in the YTJ brand blue.
/// The cat logo sits centered inside the circle.
class MorphingLoader extends StatefulWidget {
  const MorphingLoader({
    super.key,
    this.size = 240,
    this.strokeWidth = 3.5,
  });

  final double size;
  final double strokeWidth;

  @override
  State<MorphingLoader> createState() => _MorphingLoaderState();
}

class _MorphingLoaderState extends State<MorphingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _WaveRingPainter(
          animationValue: _ctrl.value,
          strokeWidth: widget.strokeWidth,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.strokeWidth + 8),
          child: const AnimatedCatLogo(size: 160),
        ),
      ),
    );
  }
}

class _WaveRingPainter extends CustomPainter {
  _WaveRingPainter({
    required this.animationValue,
    this.strokeWidth = 3.5,
  });

  final double animationValue;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // ── Draw the wave ring ────────────────────────────────────
    // The wave consists of segments around the circle.
    // A sine wave sweeps around creating a rippling effect.
    final segments = 64;
    final segmentAngle = (2 * math.pi) / segments;
    final waveCount = 3; // number of full waves around the circle
    final waveAmp = strokeWidth * 0.6; // wave amplitude

    for (var i = 0; i < segments; i++) {
      final angle = i * segmentAngle;
      // Base position
      final baseR = radius;
      // Wave offset: animate around the circle
      final waveOffset = math.sin(angle * waveCount + animationValue * 2 * math.pi);
      final r = baseR + waveOffset * waveAmp;

      // Color gradient: animate hue along the ring
      final hue = (animationValue * 360 + angle / (2 * math.pi) * 120) % 360;
      paint.color = HSVColor.fromAHSV(1, hue.toDouble(), 0.25, 0.50).toColor();

      // Draw small segment
      final x0 = center.dx + baseR * math.cos(angle);
      final y0 = center.dy + baseR * math.sin(angle);
      final x1 = center.dx + r * math.cos(angle + segmentAngle * 0.5);
      final y1 = center.dy + r * math.sin(angle + segmentAngle * 0.5);

      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), paint);
    }

    // ── Outer glow ────────────────────────────────────────────
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    glowPaint.color = _kGlowBlue.withValues(alpha: 0.15 + 0.1 * math.sin(animationValue * 2 * math.pi));
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(_WaveRingPainter old) =>
      old.animationValue != animationValue;
}

// ─── Global loader ────────────────────────────────────────────────

/// Global loading indicator: morphing wave circle + animated cat logo.
///
/// Use wherever a full-screen or inline loading indicator is needed.
/// The [message] parameter provides loading text below the animation.
class GlobalLoader extends StatelessWidget {
  const GlobalLoader({
    super.key,
    this.message,
    this.size = 240,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MorphingLoader(size: size),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
