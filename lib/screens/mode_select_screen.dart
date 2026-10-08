import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../models/match_foundation.dart';
import '../utils/constants.dart';
import '../services/settings_service.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';
import '../widgets/menu/angular_frames.dart';

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

  int _selectedModeIndex = 0;
  bool _botVsBotDoubles = false;
  int _selectedCourtIndex = 0;
  int _selectedDiffIndex = 1; // 0=Easy, 1=Medium, 2=Hard
  MatchBalanceProfile _balanceProfile = MatchBalanceProfile.standard;
  bool _initialized = false;

  final List<_ModeOption> _modes = const [
    _ModeOption('SINGLES 1v1', 'Choose difficulty & court',
        Icons.person_rounded, TilePalette.blue),
    _ModeOption('DOUBLES 2v2', 'Team up with AI partner vs AI duo',
        Icons.group_rounded, TilePalette.purple),
    _ModeOption('BOT VS BOT', 'Watch two agents compete autonomously',
        Icons.smart_toy_rounded, TilePalette.green),
    _ModeOption('ONLINE MULTIPLAYER', 'Create or join a Firebase room',
        Icons.public_rounded, TilePalette.gold),
    _ModeOption(
        'LAN MULTIPLAYER',
        'Device vs device over Wi-Fi / Local Network',
        Icons.wifi_rounded,
        TilePalette.red),
  ];

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null && args['mode'] != null) {
        final mode = args['mode'] as String;
        if (mode == 'singles') {
          _selectedModeIndex = 0;
        } else if (mode == 'doubles') {
          _selectedModeIndex = 1;
        } else if (mode == 'bot-vs-bot') {
          _selectedModeIndex = 2;
        } else if (mode == 'local') {
          _selectedModeIndex = 3;
        }
      }
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
      case 0: // Singles
        final diffs = [
          AIDifficulty.easy,
          AIDifficulty.medium,
          AIDifficulty.hard
        ];
        settings.difficulty = diffs[_selectedDiffIndex];
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/game', arguments: {
          'mode': 'singles',
          'difficulty': _selectedDiffIndex + 1,
          if (_balanceProfile != MatchBalanceProfile.standard)
            'balanceProfile': _balanceProfile.name,
        });
        break;
      case 1: // Doubles
        final diffs = [
          AIDifficulty.easy,
          AIDifficulty.medium,
          AIDifficulty.hard
        ];
        settings.difficulty = diffs[_selectedDiffIndex];
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/game', arguments: {
          'mode': 'doubles',
          'difficulty': _selectedDiffIndex + 1,
          if (_balanceProfile != MatchBalanceProfile.standard)
            'balanceProfile': _balanceProfile.name,
        });
        break;
      case 2: // Bot vs Bot spectator match
        final diffs = [
          AIDifficulty.easy,
          AIDifficulty.medium,
          AIDifficulty.hard
        ];
        settings.difficulty = diffs[_selectedDiffIndex];
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/game', arguments: {
          'mode': 'bot-vs-bot',
          'botVsBot': true,
          'gameMode': _botVsBotDoubles ? 'doubles' : 'singles',
          'difficulty': _selectedDiffIndex + 1,
          if (_balanceProfile != MatchBalanceProfile.standard)
            'balanceProfile': _balanceProfile.name,
        });
        break;
      case 3: // Online room
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/online-lobby');
        break;
      case 4: // LAN room
        context.read<SettingsService>().save(settings);
        Navigator.pushReplacementNamed(context, '/local-lobby');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = MenuMetrics.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: MenuScreen(
        title: 'CHOOSE YOUR MATCH',
        subtitle: 'Pick a format. Own the court.',
        body: _buildModeGrid(m.contentUi, m.landscape),
      ),
    );
  }

  Widget _buildModeGrid(double ui, bool landscape) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 32 * ui;
        final gap = 12 * ui;
        final wide = landscape && available >= 760 * ui;
        final cardWidth = wide ? (available - gap) / 2 : available;
        final cardHeight = (wide ? 138 : 124) * ui;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16 * ui, 12 * ui, 16 * ui, 24 * ui),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeCard(
                key: const ValueKey('mode-card-singles'),
                mode: _modes.first,
                ui: ui,
                featured: true,
                badge: 'QUICK PLAY',
                onTap: () => _showModeSetup(0, ui),
              ),
              SizedBox(height: 18 * ui),
              _buildSectionLabel('MORE WAYS TO PLAY', Icons.apps_rounded),
              SizedBox(height: 10 * ui),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: List.generate(_modes.length - 1, (offset) {
                  final i = offset + 1;
                  final mode = _modes[i];
                  return SizedBox(
                    width: cardWidth,
                    height: cardHeight,
                    child: _ModeCard(
                      key: ValueKey('mode-card-$i'),
                      mode: mode,
                      ui: ui,
                      badge: i == 2
                          ? 'SPECTATE'
                          : i == 3
                              ? 'ONLINE'
                              : i == 4
                                  ? 'LOCAL'
                                  : 'TEAM PLAY',
                      onTap: () => _showModeSetup(i, ui),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showModeSetup(int index, double ui) async {
    setState(() => _selectedModeIndex = index);
    if (index >= 3) {
      _onPlay();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, refreshDialog) => Dialog(
          backgroundColor: const Color(0xFF0F1E36),
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(18 * ui),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_modes[index].label, style: menuTitleStyle(20 * ui)),
                  SizedBox(height: 16 * ui),
                  if (index == 2) ...[
                    _buildSectionLabel('MATCH FORMAT', Icons.groups_rounded),
                    SizedBox(height: 8 * ui),
                    MenuSegmented<bool>(
                      current: _botVsBotDoubles,
                      segments: const [
                        MenuSegment(false, '1v1'),
                        MenuSegment(true, '2v2'),
                      ],
                      onChanged: (value) {
                        _botVsBotDoubles = value;
                        refreshDialog(() {});
                      },
                    ),
                    SizedBox(height: 14 * ui),
                  ],
                  _buildSectionLabel('DIFFICULTY', Icons.speed_rounded),
                  SizedBox(height: 8 * ui),
                  _buildDifficultyPicker(refreshDialog: refreshDialog),
                  SizedBox(height: 16 * ui),
                  _buildSectionLabel('SELECT COURT', Icons.stadium_rounded),
                  SizedBox(height: 8 * ui),
                  _buildCourtPicker(ui, refreshDialog: refreshDialog),
                  SizedBox(height: 10 * ui),
                  _buildSectionLabel(
                    'MATCH BALANCE',
                    Icons.balance_rounded,
                  ),
                  SizedBox(height: 4 * ui),
                  MenuSegmented<MatchBalanceProfile>(
                    height: 34,
                    current: _balanceProfile,
                    segments: const [
                      MenuSegment(
                        MatchBalanceProfile.standard,
                        'STANDARD',
                      ),
                      MenuSegment(
                        MatchBalanceProfile.competitive,
                        'COMPETITIVE',
                      ),
                    ],
                    onChanged: (value) {
                      _balanceProfile = value;
                      refreshDialog(() {});
                    },
                  ),
                  SizedBox(height: 12 * ui),
                  MenuPrimaryButton(
                    label: 'START MATCH',
                    icon: Icons.play_arrow_rounded,
                    palette: TilePalette.gold,
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _onPlay();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _showDifficulty => _selectedModeIndex < 3;

  // ignore: unused_element
  Widget _buildPortraitLayout(GameSettings settings, double ui) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14 * ui, 8 * ui, 14 * ui, 24 * ui),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('GAME MODE', Icons.sports_tennis_rounded),
          SizedBox(height: 10 * ui),
          ..._buildModeCards(ui),
          if (_selectedModeIndex == 2) ...[
            SizedBox(height: 10 * ui),
            _buildBotFormatPicker(),
          ],
          if (_showDifficulty) ...[
            SizedBox(height: 14 * ui),
            _buildSectionLabel('DIFFICULTY', Icons.speed_rounded),
            SizedBox(height: 10 * ui),
            _buildDifficultyPicker(),
          ],
          SizedBox(height: 18 * ui),
          _buildSectionLabel('SELECT COURT', Icons.stadium_rounded),
          SizedBox(height: 10 * ui),
          _buildCourtPicker(ui),
          SizedBox(height: 22 * ui),
          _buildPlayButton(),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLandscapeLayout(GameSettings settings, double ui) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: game mode (+ difficulty)
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14 * ui, 8 * ui, 8 * ui, 16 * ui),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('GAME MODE', Icons.sports_tennis_rounded),
                SizedBox(height: 10 * ui),
                ..._buildModeCards(ui),
                if (_selectedModeIndex == 2) ...[
                  SizedBox(height: 8 * ui),
                  _buildBotFormatPicker(),
                ],
                if (_showDifficulty) ...[
                  SizedBox(height: 6 * ui),
                  _buildSectionLabel('DIFFICULTY', Icons.speed_rounded),
                  SizedBox(height: 10 * ui),
                  _buildDifficultyPicker(),
                ],
              ],
            ),
          ),
        ),
        // Right: court, special shot, play — on a glass panel
        Expanded(
          flex: 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8 * ui, 8 * ui, 14 * ui, 14 * ui),
            child: MenuPanel(
              padding: EdgeInsets.all(14 * ui),
              child: Column(
                children: [
                  // Options scroll; the play button always stays in view
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(
                              'SELECT COURT', Icons.stadium_rounded),
                          SizedBox(height: 10 * ui),
                          _buildCourtPicker(ui),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12 * ui),
                  _buildPlayButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) =>
      MenuSectionTitle(text, icon: icon);

  List<Widget> _buildModeCards(double ui) {
    return List.generate(_modes.length, (i) {
      final mode = _modes[i];
      return Padding(
        padding: EdgeInsets.only(bottom: 10 * ui),
        child: MenuSelectTile(
          selected: _selectedModeIndex == i,
          palette: mode.palette,
          icon: mode.icon,
          title: mode.label,
          subtitle: mode.subtitle,
          onTap: () => setState(() => _selectedModeIndex = i),
        ),
      );
    });
  }

  Widget _buildDifficultyPicker({StateSetter? refreshDialog}) {
    return MenuSegmented<int>(
      height: 48,
      current: _selectedDiffIndex,
      segments: const [
        MenuSegment(0, 'EASY',
            icon: Icons.sentiment_satisfied_rounded,
            palette: TilePalette.green),
        MenuSegment(1, 'MEDIUM',
            icon: Icons.sentiment_neutral_rounded, palette: TilePalette.gold),
        MenuSegment(2, 'HARD',
            icon: Icons.whatshot_rounded, palette: TilePalette.red),
      ],
      onChanged: (i) {
        setState(() => _selectedDiffIndex = i);
        refreshDialog?.call(() {});
        final settings = context.read<GameSettings>();
        const diffs = [
          AIDifficulty.easy,
          AIDifficulty.medium,
          AIDifficulty.hard
        ];
        settings.difficulty = diffs[i];
        context.read<SettingsService>().save(settings);
      },
    );
  }

  Widget _buildBotFormatPicker() {
    return MenuSegmented<bool>(
      height: 44,
      current: _botVsBotDoubles,
      segments: const [
        MenuSegment(false, '1v1', icon: Icons.person_rounded),
        MenuSegment(true, '2v2', icon: Icons.groups_rounded),
      ],
      onChanged: (value) => setState(() => _botVsBotDoubles = value),
    );
  }

  Widget _buildCourtPicker(double ui, {StateSetter? refreshDialog}) {
    // All five courts side by side when they fit; a scrolling strip on
    // narrow phones.
    return LayoutBuilder(builder: (context, c) {
      final n = CourtTheme.values.length;
      final gap = 10 * ui;
      final fitWidth = (c.maxWidth - gap * (n - 1)) / n;
      if (fitWidth >= 86 * ui) {
        return SizedBox(
          height: 118 * ui,
          child: Row(
            children: [
              for (int i = 0; i < n; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: _courtCard(
                    i,
                    ui,
                    null,
                    refreshDialog: refreshDialog,
                  ),
                ),
              ],
            ],
          ),
        );
      }
      return SizedBox(
        height: 118 * ui,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: n,
          separatorBuilder: (_, __) => SizedBox(width: gap),
          itemBuilder: (_, i) => _courtCard(
            i,
            ui,
            112 * ui,
            refreshDialog: refreshDialog,
          ),
        ),
      );
    });
  }

  Widget _courtCard(
    int i,
    double ui,
    double? width, {
    StateSetter? refreshDialog,
  }) {
    final theme = CourtTheme.values[i];
    final selected = _selectedCourtIndex == i;
    final radius = 12 * ui;

    final colors = selected
        ? TilePalette.blue.colors
        : [
            kMenuPanelColor,
            kMenuPanelColor.withAlpha(220),
          ];
    final borderColor = selected ? TilePalette.blue.border : kMenuPanelBorder;

    return MenuPressable(
      key: ValueKey('court-${theme.name}-$selected'),
      onTap: () {
        setState(() => _selectedCourtIndex = i);
        refreshDialog?.call(() {});
      },
      pressedScale: 1.035, // Snappy scale-up matching main menu tiles
      child: ShineSweep(
        autoPeriodic: selected,
        periodicInterval: const Duration(seconds: 5),
        shineColor:
            selected ? const Color(0x66FFFFFF) : const Color(0x22FFFFFF),
        clipper: SingleSlantedClipper(
          angleDegrees: 7.0,
          radius: radius,
          direction: SlantDirection.forward,
        ),
        child: SizedBox(
          width: width,
          child: CustomPaint(
            painter: SingleSlantedFramePainter(
              colors: colors,
              borderColor: borderColor,
              borderWidth: selected ? 2.0 : 1.5,
              angleDegrees:
                  7.0, // Matching 7° athletic slant on right edge only
              radius: radius,
              direction: SlantDirection.forward,
            ),
            child: ClipPath(
              clipper: SingleSlantedClipper(
                angleDegrees: 7.0,
                radius: radius,
                direction: SlantDirection.forward,
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x38FFFFFF),
                              Color(0x00FFFFFF),
                              Color(0x00000000),
                              Color(0x22000000),
                            ],
                            stops: [0.0, 0.45, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8 * ui, vertical: 8 * ui),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniCourtThumbnail(theme: theme, scale: ui),
                        ParallelogramBadge(
                          color: selected
                              ? Colors.white.withAlpha(46)
                              : kMenuTrack,
                          borderColor:
                              selected ? Colors.white.withAlpha(120) : null,
                          padding: EdgeInsets.symmetric(
                              horizontal: 7 * ui, vertical: 2 * ui),
                          child: Text(
                            theme.badgeLabel,
                            style: TextStyle(
                              fontSize: 8.5 * ui,
                              fontFamily: AppFonts.orbitron,
                              fontWeight: FontWeight.w900,
                              color: selected ? Colors.white : kMenuMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(theme.icon,
                                  size: 13 * ui,
                                  color: selected ? kMenuGold : kMenuMuted),
                              SizedBox(width: 4 * ui),
                              Text(
                                theme.displayName,
                                style: TextStyle(
                                  fontSize: 10 * ui,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 5 * ui,
                      right: 5 * ui,
                      child: Icon(Icons.check_circle_rounded,
                          size: 18 * ui, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return MenuPrimaryButton(
      label: 'PLAY NOW',
      icon: Icons.play_arrow_rounded,
      palette: TilePalette.gold,
      onTap: _onPlay,
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _ModeOption mode;
  final double ui;
  final bool featured;
  final String badge;
  final VoidCallback onTap;

  const _ModeCard({
    super.key,
    required this.mode,
    required this.ui,
    required this.badge,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 18 * ui;
    return Semantics(
      button: true,
      label: '${mode.label}. ${mode.subtitle}',
      child: MenuPressable(
        onTap: onTap,
        child: Container(
          height: featured ? 158 * ui : null,
          constraints: BoxConstraints(minHeight: featured ? 148 * ui : 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mode.palette.colors.first,
                mode.palette.colors[1],
                mode.palette.colors.last,
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: mode.palette.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: mode.palette.colors.last.withAlpha(105),
                blurRadius: featured ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: Stack(
              children: [
                Positioned(
                  right: -18 * ui,
                  bottom: -26 * ui,
                  child: Icon(
                    mode.icon,
                    size: (featured ? 156 : 116) * ui,
                    color: Colors.white.withAlpha(24),
                  ),
                ),
                Positioned(
                  left: -30 * ui,
                  top: -55 * ui,
                  child: Container(
                    width: 150 * ui,
                    height: 150 * ui,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(18),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all((featured ? 20 : 16) * ui),
                  child: Row(
                    children: [
                      Container(
                        width: (featured ? 72 : 58) * ui,
                        height: (featured ? 72 : 58) * ui,
                        decoration: BoxDecoration(
                          color: const Color(0x3308172C),
                          borderRadius: BorderRadius.circular(18 * ui),
                          border: Border.all(color: Colors.white.withAlpha(80)),
                        ),
                        child: Icon(
                          mode.icon,
                          size: (featured ? 39 : 31) * ui,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16 * ui),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * ui,
                                vertical: 3 * ui,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x3D071426),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(65),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: AppFonts.orbitron,
                                  fontSize: 8.5 * ui,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            SizedBox(height: 8 * ui),
                            Text(
                              mode.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: menuTitleStyle((featured ? 23 : 17) * ui),
                            ),
                            SizedBox(height: 4 * ui),
                            Text(
                              mode.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(215),
                                fontSize: (featured ? 12 : 10.5) * ui,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * ui),
                      Container(
                        width: 38 * ui,
                        height: 38 * ui,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withAlpha(70)),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 21 * ui,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOption {
  final String label;
  final String subtitle;
  final IconData icon;
  final TilePalette palette;
  const _ModeOption(this.label, this.subtitle, this.icon, this.palette);
}

class _MiniCourtThumbnail extends StatelessWidget {
  final CourtTheme theme;
  final double scale;
  const _MiniCourtThumbnail({required this.theme, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70 * scale,
      height: 44 * scale,
      decoration: BoxDecoration(
        color: theme.apronColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
        border: Border.all(
          color: theme.ledAccentColor.withAlpha(120),
          width: 0.9,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              theme.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => CustomPaint(
                painter: _MiniCourtPainter(theme: theme),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withAlpha(35),
                  width: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCourtPainter extends CustomPainter {
  final CourtTheme theme;
  const _MiniCourtPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Apron padding around the court: 5px on sides, 3.5px top/bottom
    const padX = 5.0;
    const padY = 3.5;
    final courtRect =
        Rect.fromLTRB(padX, padY, size.width - padX, size.height - padY);

    // 2. Court Playing Surface with gradient
    final courtPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          theme.surfaceColorDark,
          theme.surfaceColor,
          theme.surfaceColorLight
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(courtRect);
    canvas.drawRect(courtRect, courtPaint);

    // 4. Non-Volley Zone (The Kitchen) in the center (32% of court length)
    final centerY = courtRect.center.dy;
    final kitchenHalfH = courtRect.height * 0.17;
    final kitchenRect = Rect.fromLTRB(
      courtRect.left,
      centerY - kitchenHalfH,
      courtRect.right,
      centerY + kitchenHalfH,
    );

    final kitchenPaint = Paint()
      ..shader = LinearGradient(
        colors: [theme.kitchenColorDark, theme.kitchenColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(kitchenRect);
    canvas.drawRect(kitchenRect, kitchenPaint);

    // 5. Regulation White Lines
    final linePaint = Paint()
      ..color = theme.lineColor.withAlpha(220)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    // Court boundary (baselines and sidelines)
    canvas.drawRect(courtRect, linePaint);

    // Kitchen lines (top and bottom of kitchen)
    canvas.drawLine(Offset(courtRect.left, kitchenRect.top),
        Offset(courtRect.right, kitchenRect.top), linePaint);
    canvas.drawLine(Offset(courtRect.left, kitchenRect.bottom),
        Offset(courtRect.right, kitchenRect.bottom), linePaint);

    // Center service lines (from baselines to kitchen lines)
    final midX = courtRect.center.dx;
    canvas.drawLine(
        Offset(midX, courtRect.top), Offset(midX, kitchenRect.top), linePaint);
    canvas.drawLine(Offset(midX, kitchenRect.bottom),
        Offset(midX, courtRect.bottom), linePaint);

    // 6. Net across the center (z=0)
    canvas.drawLine(
      Offset(courtRect.left - 2, centerY),
      Offset(courtRect.right + 2, centerY),
      Paint()
        ..color = const Color(0xCC0F172A)
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(courtRect.left - 2, centerY - 0.4),
      Offset(courtRect.right + 2, centerY - 0.4),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 0.8,
    );
    // Net post pins
    final postPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawCircle(Offset(courtRect.left - 2.5, centerY), 1.2, postPaint);
    canvas.drawCircle(Offset(courtRect.right + 2.5, centerY), 1.2, postPaint);

    // 7. Subtle diagonal sheen
    final sheenPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.45, 0)
      ..lineTo(0, size.height * 0.75)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x35FFFFFF), Color(0x00FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(
            Rect.fromLTWH(0, 0, size.width * 0.45, size.height * 0.75)),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniCourtPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
