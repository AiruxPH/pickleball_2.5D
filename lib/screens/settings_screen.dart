import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Settings Screen
/// ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── App Bar ─────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildAppBar(context),
                ),

                // ── Sections ─────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),

                      // ── AI Difficulty ────────────────────
                      _SettingsSection(
                        title: 'GAME',
                        icon: Icons.sports_tennis,
                        children: [
                          _SettingsLabel(
                            label: 'AI Difficulty',
                            value: settings.difficulty.name.toUpperCase(),
                            valueColor: settings.difficulty == AIDifficulty.easy
                                ? AppColors.secondary
                                : settings.difficulty == AIDifficulty.medium
                                    ? AppColors.primary
                                    : AppColors.scoreAI,
                          ),
                          const SizedBox(height: 10),
                          _DifficultySelector(
                            current: settings.difficulty,
                            onChange: (d) {
                              settings.difficulty = d;
                              _saveSettings(context, settings);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settings.difficulty == AIDifficulty.easy
                                ? '• Relaxed pace & centered returns — great for rallies'
                                : settings.difficulty == AIDifficulty.medium
                                    ? '• Balanced club player with moderate speed & shot variety'
                                    : '• Championship pro — aggressive corner drives, smashes & dinks',
                            style: TextStyle(
                              color: AppColors.textMuted.withAlpha(200),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Graphics ─────────────────────────
                      _SettingsSection(
                        title: 'GRAPHICS',
                        icon: Icons.auto_awesome,
                        children: [
                          _SettingsLabel(
                            label: 'Quality',
                            value: settings.graphicsQuality.name.toUpperCase(),
                          ),
                          const SizedBox(height: 10),
                          _QualitySelector(
                            current: settings.graphicsQuality,
                            onChange: (q) {
                              settings.graphicsQuality = q;
                              _saveSettings(context, settings);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Audio ─────────────────────────────
                      _SettingsSection(
                        title: 'AUDIO',
                        icon: Icons.volume_up_rounded,
                        children: [
                          _SliderRow(
                            label: 'Music Volume',
                            value: settings.musicVolume,
                            onChanged: (v) {
                              settings.musicVolume = v;
                              try {
                                context.read<AudioService>().setMusicVolume(v);
                              } catch (_) {}
                              _saveSettings(context, settings);
                            },
                          ),
                          const SizedBox(height: 12),
                          _SliderRow(
                            label: 'Sound Effects',
                            value: settings.sfxVolume,
                            onChanged: (v) {
                              settings.sfxVolume = v;
                              try {
                                context.read<AudioService>().setSfxVolume(v);
                              } catch (_) {}
                              _saveSettings(context, settings);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Controls ──────────────────────────
                      _SettingsSection(
                        title: 'CONTROLS',
                        icon: Icons.gamepad_rounded,
                        children: [
                          _SliderRow(
                            label: 'Joystick Sensitivity',
                            value: (settings.joystickSensitivity - 0.5) / 1.5,
                            onChanged: (v) {
                              settings.joystickSensitivity = 0.5 + v * 1.5;
                              _saveSettings(context, settings);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Low',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                Text(
                                  '${settings.joystickSensitivity.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                ),
                                const Text('High',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
            shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
            child: const Text(
              'SETTINGS',
              style: TextStyle(
                fontFamily: AppFonts.orbitron,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings(
      BuildContext context, GameSettings settings) async {
    final svc = context.read<SettingsService>();
    await svc.save(settings);
  }
}

// ── Sections ────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.orbitron,
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SettingsLabel({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Difficulty selector ──────────────────────────────────────────
class _DifficultySelector extends StatelessWidget {
  final AIDifficulty current;
  final ValueChanged<AIDifficulty> onChange;

  const _DifficultySelector({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final options = [
      (AIDifficulty.easy, 'EASY', AppColors.secondary),
      (AIDifficulty.medium, 'MEDIUM', AppColors.primary),
      (AIDifficulty.hard, 'HARD', AppColors.scoreAI),
    ];

    return Row(
      children: options.map((opt) {
        final (diff, label, color) = opt;
        final isSelected = current == diff;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChange(diff),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? color.withAlpha(30) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.white24,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontFamily: AppFonts.orbitron,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Graphics quality selector ────────────────────────────────────
class _QualitySelector extends StatelessWidget {
  final GraphicsQuality current;
  final ValueChanged<GraphicsQuality> onChange;

  const _QualitySelector({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final options = [
      (GraphicsQuality.low, 'LOW'),
      (GraphicsQuality.medium, 'MEDIUM'),
      (GraphicsQuality.high, 'HIGH'),
    ];

    return Row(
      children: options.map((opt) {
        final (quality, label) = opt;
        final isSelected = current == quality;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChange(quality),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(30)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white24,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontFamily: AppFonts.orbitron,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Slider row ──────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.textMuted.withAlpha(80),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primaryGlow,
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
