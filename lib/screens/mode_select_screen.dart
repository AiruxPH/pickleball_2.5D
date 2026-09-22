import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/ultimate_skill.dart';
import '../utils/constants.dart';
import '../services/settings_service.dart';

/// ─────────────────────────────────────────────────────────────
/// Mode Select Screen — choose game mode + court + difficulty
/// ─────────────────────────────────────────────────────────────

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;

  int _selectedModeIndex = 0; // 0=Quick, 1=Singles, 2=Training
  int _selectedCourtIndex = 0;
  int _selectedDiffIndex = 1; // 0=Easy, 1=Medium, 2=Hard
  bool _initialized = false;

  final List<_ModeOption> _modes = const [
    _ModeOption('QUICK MATCH', 'Jump right in — standard settings', Icons.flash_on_rounded, Color(0xFFF59E0B)),
    _ModeOption('SINGLES 1v1', 'Choose difficulty & court', Icons.person_rounded, Color(0xFF38BDF8)),
    _ModeOption('TRAINING', 'Practice drills, no scoring', Icons.fitness_center_rounded, Color(0xFF34D399)),
  ];

  final List<String> _diffs = ['EASY', 'MEDIUM', 'HARD'];
  final List<Color> _diffColors = [
    const Color(0xFF34D399),
    const Color(0xFFF59E0B),
    const Color(0xFFF43F5E),
  ];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final settings = context.read<GameSettings>();
      _selectedDiffIndex = settings.difficulty.index;
      _selectedCourtIndex = settings.courtTheme.index;
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  void _onPlay() {
    final settings = context.read<GameSettings>();
    HapticFeedback.mediumImpact();

    final court = CourtTheme.values[_selectedCourtIndex];
    settings.courtTheme = court;

    switch (_selectedModeIndex) {
      case 0: // Quick Match: uses current user difficulty setting
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/game',
            arguments: {'mode': 'singles', 'difficulty': settings.difficulty.index + 1});
        break;
      case 1: // Singles
        final diffs = [AIDifficulty.easy, AIDifficulty.medium, AIDifficulty.hard];
        settings.difficulty = diffs[_selectedDiffIndex];
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/game',
            arguments: {'mode': 'singles', 'difficulty': _selectedDiffIndex + 1});
        break;
      case 2: // Training
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/training');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(settings)
              : _buildPortraitLayout(settings),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(GameSettings settings) {
    return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('GAME MODE'),
                      const SizedBox(height: 12),
                      ..._buildModeCards(),
                      const SizedBox(height: 24),
                      if (_selectedModeIndex == 1) ...[
                        _buildSectionLabel('DIFFICULTY'),
                        const SizedBox(height: 12),
                        _buildDifficultyPicker(),
                        const SizedBox(height: 24),
                      ],
                      _buildSectionLabel('SELECT COURT'),
                      const SizedBox(height: 12),
                      _buildCourtPicker(),
                      const SizedBox(height: 24),
                      _buildSectionLabel('SIGNATURE ULTIMATE'),
                      const SizedBox(height: 12),
                      _buildUltimatePicker(settings),
                      const SizedBox(height: 32),
                      _buildPlayButton(),
                    ],
                  ),
                ),
              ),
            ],
    );
  }

  Widget _buildLandscapeLayout(GameSettings settings) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left column: Game mode + difficulty
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('GAME MODE'),
                      const SizedBox(height: 10),
                      ..._buildModeCards(),
                      if (_selectedModeIndex == 1) ...[
                        const SizedBox(height: 14),
                        _buildSectionLabel('DIFFICULTY'),
                        const SizedBox(height: 10),
                        _buildDifficultyPicker(),
                      ],
                    ],
                  ),
                ),
              ),

              // Vertical divider
              Container(
                width: 1,
                color: Colors.white.withAlpha(20),
                margin: const EdgeInsets.symmetric(vertical: 12),
              ),

              // Right column: Court + Ultimate + Play
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel('SELECT COURT'),
                      const SizedBox(height: 10),
                      _buildCourtPicker(),
                      const SizedBox(height: 14),
                      _buildSectionLabel('SIGNATURE ULTIMATE'),
                      const SizedBox(height: 10),
                      _buildUltimatePicker(settings),
                      const SizedBox(height: 20),
                      _buildPlayButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'SELECT MODE',
            style: TextStyle(
              fontFamily: AppFonts.orbitron,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.orbitron,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 2,
      ),
    );
  }

  List<Widget> _buildModeCards() {
    return List.generate(_modes.length, (i) {
      final m = _modes[i];
      final selected = _selectedModeIndex == i;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedModeIndex = i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? m.color.withAlpha(25) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? m.color : const Color(0xFF334155),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: m.color.withAlpha(60), blurRadius: 16)]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: m.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label, style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? m.color : Colors.white,
                      letterSpacing: 1,
                    )),
                    const SizedBox(height: 2),
                    Text(m.subtitle, style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    )),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: m.color, size: 20),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDifficultyPicker() {
    return Row(
      children: List.generate(3, (i) {
        final selected = _selectedDiffIndex == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDiffIndex = i);
              final settings = context.read<GameSettings>();
              final diffs = [AIDifficulty.easy, AIDifficulty.medium, AIDifficulty.hard];
              settings.difficulty = diffs[i];
              context.read<SettingsService>().save(settings);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? _diffColors[i].withAlpha(25) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _diffColors[i] : const Color(0xFF334155),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    i == 0 ? Icons.sentiment_satisfied_rounded
                        : i == 1 ? Icons.sentiment_neutral_rounded
                        : Icons.sentiment_very_dissatisfied_rounded,
                    color: selected ? _diffColors[i] : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _diffs[i],
                    style: TextStyle(
                      fontFamily: AppFonts.orbitron,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? _diffColors[i] : Colors.white54,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCourtPicker() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: CourtTheme.values.length,
        itemBuilder: (_, i) {
          final theme = CourtTheme.values[i];
          final selected = _selectedCourtIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCourtIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              margin: EdgeInsets.only(right: i < CourtTheme.values.length - 1 ? 10 : 0),
              decoration: BoxDecoration(
                color: selected ? theme.surfaceColor.withAlpha(40) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? theme.surfaceColor : const Color(0xFF334155),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mini court preview
                  Container(
                    width: 50,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.surfaceColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Center(child: Container(width: 46, height: 1, color: Colors.white54)),
                        Center(child: Container(width: 1, height: 28, color: Colors.white54)),
                        Positioned(top: 0, left: 0, right: 0,
                          child: Container(height: 1, color: Colors.white)),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: Container(height: 1, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    theme.emoji,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    theme.displayName.split(' ').first,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: selected ? theme.surfaceColor : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUltimatePicker(GameSettings settings) {
    final current = settings.equippedUltimate;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kAllUltimateSkills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final skill = kAllUltimateSkills[i];
          final isSelected = skill.type == current;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              settings.equipUltimate(skill.type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 155,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? skill.primaryColor.withAlpha(35)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? skill.primaryColor
                      : const Color(0xFF334155),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: skill.glowColor,
                      blurRadius: 10,
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: skill.primaryColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(skill.icon,
                        color: skill.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          skill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          skill.japaneseName,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: skill.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: AppColors.primaryGlow,
        ),
        onPressed: _onPlay,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 22),
            const SizedBox(width: 8),
            Text(
              _selectedModeIndex == 2 ? 'START TRAINING' : 'PLAY NOW',
              style: const TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _ModeOption(this.label, this.subtitle, this.icon, this.color);
}
