import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Animated Splash Screen
/// Shows for ~2.5s with animated pickleball, title fade-in,
/// scale animation, and loading bar, then navigates to menu.
/// ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Fade in animation for the whole screen
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Scale/pop animation for the logo
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  // Ball bounce animation
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  // Ball rotation
  late AnimationController _rotateController;
  late Animation<double> _rotateAnim;

  // Loading bar progress
  late AnimationController _loadController;
  late Animation<double> _loadAnim;

  // Subtitle fade in
  late AnimationController _subtitleController;
  late Animation<double> _subtitleAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSequence();
  }

  void _initAnimations() {
    // Overall fade-in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    // Logo scale pop
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Ball bounce (repeating)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    );

    // Ball rotation (repeating)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 2 * math.pi)
        .animate(_rotateController);

    // Loading bar
    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadAnim = CurvedAnimation(parent: _loadController, curve: Curves.easeInOut);

    // Subtitle fade-in (delayed)
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _subtitleAnim =
        CurvedAnimation(parent: _subtitleController, curve: Curves.easeIn);
  }

  Future<void> _startSequence() async {
    // Start fade in immediately
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();

    // Start bounce (looping)
    _bounceController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 400));
    _subtitleController.forward();

    // Start loading bar
    _loadController.forward();

    // Wait for loading to finish (~2.4s total)
    await Future.delayed(const Duration(milliseconds: 2400));

    if (!mounted) return;
    // Fade out and navigate
    await _fadeController.reverse();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/menu');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _bounceController.dispose();
    _rotateController.dispose();
    _loadController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyTop,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF1E88E5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // ── Cloud decorations ──────────────────────────────
              const Positioned(
                top: 40,
                left: 10,
                child: Opacity(
                  opacity: 0.35,
                  child: CustomPaint(
                    size: Size(130, 65),
                    painter: _SplashCloudPainter(),
                  ),
                ),
              ),
              const Positioned(
                top: 80,
                right: 20,
                child: Opacity(
                  opacity: 0.25,
                  child: CustomPaint(
                    size: Size(100, 50),
                    painter: _SplashCloudPainter(),
                  ),
                ),
              ),

              // ── Main content ──────────────────────────────────
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Animated Ball ───────────────────────────
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_bounceAnim, _rotateAnim, _scaleAnim]),
                      builder: (context, child) {
                        final bounceOffset = (1 - _bounceAnim.value) * 30;
                        return Transform.translate(
                          offset: Offset(0, bounceOffset),
                          child: Transform.scale(
                            scale: _scaleAnim.value,
                            child: Transform.rotate(
                              angle: _rotateAnim.value,
                              child: const _PickleballWidget(size: 120),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // ── Game Title (PS style) ─────────────────────
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: const Column(
                        children: [
                          // Stroked text — PICKLEBALL
                          _StrokedLogoText(
                            text: 'PICKLEBALL',
                            fontSize: 36,
                            strokeColor: Color(0xFF0D47A1),
                            fillColor: Color(0xFFFFC200),
                            letterSpacing: 4,
                          ),
                          // Stroked text — STARS
                          _StrokedLogoText(
                            text: 'STARS',
                            fontSize: 60,
                            strokeColor: Color(0xFF0D47A1),
                            fillColor: Color(0xFFFFC200),
                            letterSpacing: 6,
                            height: 0.85,
                          ),
                          SizedBox(height: 10),
                          // 3 gold stars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, color: Color(0xFFFFD740), size: 36,
                                shadows: [Shadow(color: Color(0xFFFFC200), blurRadius: 10)]),
                              Icon(Icons.star_rounded, color: Color(0xFFFFD740), size: 36,
                                shadows: [Shadow(color: Color(0xFFFFC200), blurRadius: 10)]),
                              Icon(Icons.star_rounded, color: Color(0xFFFFD740), size: 36,
                                shadows: [Shadow(color: Color(0xFFFFC200), blurRadius: 10)]),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Subtitle ──────────────────────────────────
                    FadeTransition(
                      opacity: _subtitleAnim,
                      child: const Text(
                        'Compete  •  Upgrade  •  Champion!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Color(0xFF0D47A1), blurRadius: 4)
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // ── Loading bar (yellow) ──────────────────────
                    FadeTransition(
                      opacity: _subtitleAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: AnimatedBuilder(
                          animation: _loadAnim,
                          builder: (context, _) => Column(
                            children: [
                              Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0x440D47A1),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: const Color(0xFF0D47A1),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: _loadAnim.value,
                                    backgroundColor: Colors.transparent,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFFFC200)),
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'LOADING  ${(_loadAnim.value * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pickleball Widget (drawn with CustomPainter) ─────────────────
class _PickleballWidget extends StatelessWidget {
  final double size;
  const _PickleballWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PickleballPainter()),
    );
  }
}

class _PickleballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Ball body — bright yellow (PS style)
    final ballPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFEE44), Color(0xFFFFC200), Color(0xFFE5A000)],
        center: Alignment(-0.3, -0.4),
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, ballPaint);

    // Ball outline
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFFAA7700).withAlpha(120)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Pickleball holes (arranged in circular pattern)
    final holePaint = Paint()
      ..color = const Color(0xFFCC8800).withAlpha(180)
      ..style = PaintingStyle.fill;

    const holeRadius = 5.0;
    const angles = [0.0, 1.05, 2.1, 3.14, 4.19, 5.24];
    for (final a in angles) {
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(a) * radius * 0.55,
          center.dy + math.sin(a) * radius * 0.55,
        ),
        holeRadius,
        holePaint,
      );
    }
    // Center hole
    canvas.drawCircle(center, holeRadius * 0.8, holePaint);

    // Glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFC200).withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 14);
    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(_PickleballPainter oldDelegate) => false;
}

// ── Stroked logo text widget ─────────────────────────────────
class _StrokedLogoText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color strokeColor;
  final Color fillColor;
  final double letterSpacing;
  final double height;

  const _StrokedLogoText({
    required this.text,
    required this.fontSize,
    required this.strokeColor,
    required this.fillColor,
    this.letterSpacing = 2,
    this.height = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.orbitron,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: height,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: style.copyWith(color: fillColor),
        ),
      ],
    );
  }
}

// ── Splash cloud painter ────────────────────────────────────
class _SplashCloudPainter extends CustomPainter {
  const _SplashCloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.65), h * 0.35, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), h * 0.45, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.65), h * 0.35, paint);
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.65, w * 0.7, h * 0.35), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
