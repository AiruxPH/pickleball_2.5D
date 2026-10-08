import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/menu_backdrop.dart';
import 'main_menu_screen.dart';

/// ─────────────────────────────────────────────────────────────
/// Splash Screen
///
/// Uses the main menu's scene art in exactly the same position, with a
/// loading panel where the menu tiles will appear. When loading finishes it
/// cross-fades straight into the menu: the characters and logo stay still
/// and the menu UI appears on top of them.
/// ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _tips = [
    'The serve must land past the kitchen line, diagonally across the court.',
    'Let the ball bounce once on each side before anyone volleys.',
    'You can\'t volley while standing in the kitchen.',
    'Long rallies fill your special-shot meter faster.',
    'Soft dinks into the kitchen are hard to attack.',
  ];

  late final AnimationController _intro; // art fades in and settles
  late final AnimationController _load; // loading bar
  late final String _tip = _tips[math.Random().nextInt(_tips.length)];
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _load = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _load.forward();
    });
    _load.addStatusListener((s) {
      if (s == AnimationStatus.completed) _goToMenu();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm up the menu's artwork so the hand-off has no pop-in
    if (!_precached) {
      _precached = true;
      for (final a in const [
        'assets/images/menu/menu_background.jpg',
        'assets/images/menu/avatar_boy.png',
        'assets/images/menu/play_ball.png',
      ]) {
        precacheImage(AssetImage(a), context);
      }
    }
  }

  Future<void> _goToMenu() async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: '/menu'),
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainMenuScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = MenuMetrics.of(context);
    final ui = m.ui;
    final settle = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    final panelIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );

    final panel = FadeTransition(
      opacity: panelIn,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(panelIn),
        child: _LoadingPanel(ui: ui, progress: _load, tip: _tip),
      ),
    );

    return Scaffold(
      backgroundColor: kMenuCourtBlue,
      body: Stack(
        children: [
          // Same art, same place as the menu; it fades in and settles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: settle,
              builder: (_, __) => MenuBackdrop(
                artOpacity: settle.value,
                artScale: 1.06 - 0.06 * settle.value,
              ),
            ),
          ),

          // Content area above the (menu-matching) bottom bar
          Positioned.fill(
            bottom: m.navHeight,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(14 * ui),
                child: m.landscape
                    // Loading panel sits where the menu tiles will appear
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(width: m.tilesWidth, child: panel),
                      )
                    // Portrait: panel centred in the space under the logo
                    : Column(
                        children: [
                          SizedBox(height: m.heroHeight * 0.84),
                          Expanded(child: Center(child: panel)),
                        ],
                      ),
              ),
            ),
          ),

          // Same bar as the menu's navigation, so its buttons fade into place
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: m.navHeight,
            child: FadeTransition(
              opacity: panelIn,
              child: Container(
                padding: EdgeInsets.only(bottom: m.bottomInset),
                decoration: const BoxDecoration(
                  color: Color(0xF20C1A33),
                  border: Border(top: BorderSide(color: kMenuPanelBorder)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 12,
                        offset: Offset(0, -2)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'PICKLEBALL CHAMPIONS',
                  style: TextStyle(
                    color: const Color(0xFF6F84A6),
                    fontSize: 11 * ui,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3 * ui,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final double ui;
  final Animation<double> progress;
  final String tip;

  const _LoadingPanel({
    required this.ui,
    required this.progress,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final eased = CurvedAnimation(parent: progress, curve: Curves.easeInOut);

    return Container(
      padding: EdgeInsets.fromLTRB(18 * ui, 16 * ui, 18 * ui, 18 * ui),
      decoration: BoxDecoration(
        color: kMenuPanelColor,
        borderRadius: BorderRadius.circular(18 * ui),
        border: Border.all(color: kMenuPanelBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: AnimatedBuilder(
        animation: eased,
        builder: (context, _) {
          final pct = (eased.value * 100).round();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_tennis_rounded,
                      color: const Color(0xFFFFC21A), size: 24 * ui),
                  SizedBox(width: 10 * ui),
                  Text(
                    pct >= 100 ? 'READY!' : 'LOADING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * ui,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: const Color(0xFFFFC21A),
                      fontSize: 16 * ui,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12 * ui),
              // Same gold-to-blue bar as the menu's XP bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6 * ui),
                child: SizedBox(
                  height: 12 * ui,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                          child: ColoredBox(color: Color(0xFF1D3357))),
                      FractionallySizedBox(
                        widthFactor: eased.value,
                        heightFactor: 1.0,
                        alignment: Alignment.centerLeft,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD54A), Color(0xFF4DA3FF)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14 * ui),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: const Color(0xFFB8C7E0), size: 18 * ui),
                  SizedBox(width: 8 * ui),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: const Color(0xFFD7E2F3),
                        fontSize: 13 * ui,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
