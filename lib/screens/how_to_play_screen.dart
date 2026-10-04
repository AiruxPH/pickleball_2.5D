import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// How To Play Screen — illustrated controls guide
/// ─────────────────────────────────────────────────────────────

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _currentPage = 0;

  static const _pages = [
    _HowToPage(
      icon: Icons.gamepad_rounded,
      title: 'MOVE',
      color: AppColors.primary,
      steps: [
        'Use the virtual joystick on the left side of the screen.',
        'Push in any direction to move your player.',
        'Move forward to reach the kitchen zone.',
        'Stay behind the kitchen line unless you are volleying.',
      ],
    ),
    _HowToPage(
      icon: Icons.sports_tennis,
      title: 'HIT',
      color: AppColors.secondary,
      steps: [
        'Tap the HIT button when the ball is near your player.',
        'Timing matters — hit just as the ball reaches you.',
        'The closer you are to the ball, the better your hit.',
        'You can hit both forehand and backhand automatically.',
      ],
    ),
    _HowToPage(
      icon: Icons.bolt_rounded,
      title: 'POWER SHOT',
      color: AppColors.power,
      steps: [
        'Tap or hold the POWER button for a stronger shot.',
        'Power shots travel faster and lower over the net.',
        'Use power shots sparingly — they cost more energy.',
        'A blue trail appears on normal shots, orange on power shots.',
      ],
    ),
    _HowToPage(
      icon: Icons.swipe_rounded,
      title: 'AIM',
      color: AppColors.primary,
      steps: [
        'Swipe left or right to aim your shot direction.',
        'Swipe up for a lob shot over the opponent.',
        'Combine joystick movement + swipe for precise shots.',
        'Aim into the corners for the best angles.',
      ],
    ),
    _HowToPage(
      icon: Icons.sports_baseball,
      title: 'SERVE',
      color: AppColors.secondary,
      steps: [
        'Press the SERVE button to begin each rally.',
        'The ball must land in the opposite service box.',
        'The serve must clear the net and the kitchen zone.',
        'You alternate serve sides after each point you win.',
      ],
    ),
    _HowToPage(
      icon: Icons.workspace_premium_rounded,
      title: 'SCORING',
      color: Color(0xFFFFCC00),
      steps: [
        'First to 11 points wins the match.',
        'You must win by at least 2 points.',
        'If the ball lands out — opponent scores.',
        'If you hit the net — opponent scores.',
        'If the ball bounces twice on your side — opponent scores.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _currentPage = index);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.primaryGradient.createShader(b),
                      child: const Text(
                        'HOW TO PLAY',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: page.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: page.color.withAlpha(100)),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_pages.length}',
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: page.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Responsive Content ────────────────────────
              Expanded(
                child: isLandscape
                    ? _buildLandscapeLayout(page)
                    : _buildPortraitLayout(page),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(_HowToPage page) {
    return Column(
      children: [
        // Page dots
        _buildDots(page),
        const SizedBox(height: 16),

        // Scrollable content
        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: page.color.withAlpha(20),
                          border: Border.all(
                              color: page.color.withAlpha(80), width: 2),
                        ),
                        child: Icon(page.icon, color: page.color, size: 40),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        page.title,
                        style: TextStyle(
                          fontFamily: AppFonts.orbitron,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: page.color,
                          letterSpacing: 3,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Steps
                      ...page.steps.asMap().entries.map((entry) {
                        return _StepRow(
                          number: entry.key + 1,
                          text: entry.value,
                          color: page.color,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildNavigationButtons(page),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(_HowToPage page) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xB3121D34),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: page.color.withAlpha(70)),
              boxShadow: [
                BoxShadow(color: page.color.withAlpha(18), blurRadius: 28),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            page.color.withAlpha(34),
                            const Color(0xFF10192D),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LESSON ${(_currentPage + 1).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: page.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: page.color.withAlpha(22),
                              border: Border.all(color: page.color.withAlpha(120)),
                            ),
                            child: Icon(page.icon, color: page.color, size: 42),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            page.title,
                            style: const TextStyle(
                              fontFamily: AppFonts.orbitron,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Master the fundamentals, then take them onto the court.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildDots(page),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 22, 30, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COURT NOTES',
                          style: TextStyle(
                            fontFamily: AppFonts.orbitron,
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: FadeTransition(
                            opacity: _fade,
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: page.steps.asMap().entries.map((entry) {
                                  return _StepRow(
                                    number: entry.key + 1,
                                    text: entry.value,
                                    color: page.color,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNavigationButtons(page),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(_HowToPage page) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _currentPage;
        return GestureDetector(
          onTap: () => _goToPage(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? page.color : AppColors.textMuted.withAlpha(100),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavigationButtons(_HowToPage page) {
    return Row(
      children: [
        if (_currentPage > 0)
          Expanded(
            child: _NavButton(
              label: 'BACK',
              leadingIcon: Icons.arrow_back_rounded,
              onTap: () => _goToPage(_currentPage - 1),
              isPrimary: false,
            ),
          ),
        if (_currentPage > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _currentPage < _pages.length - 1
              ? _NavButton(
                  label: 'NEXT',
                  trailingIcon: Icons.arrow_forward_rounded,
                  onTap: () => _goToPage(_currentPage + 1),
                  isPrimary: true,
                  color: page.color,
                )
              : _NavButton(
                  label: "PLAY NOW",
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/game'),
                  isPrimary: true,
                  color: AppColors.secondary,
                ),
        ),
      ],
    );
  }
}

class _HowToPage {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> steps;

  const _HowToPage({
    required this.icon,
    required this.title,
    required this.color,
    required this.steps,
  });
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  final Color color;

  const _StepRow({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const _NavButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.color,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isPrimary ? c.withAlpha(25) : AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? c.withAlpha(150) : Colors.white24,
            width: 1.5,
          ),
          boxShadow: isPrimary
              ? [BoxShadow(color: c.withAlpha(40), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: isPrimary ? c : AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? c : AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 18, color: isPrimary ? c : AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
