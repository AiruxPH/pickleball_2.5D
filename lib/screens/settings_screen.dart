import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_settings.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../widgets/menu_backdrop.dart';
import '../widgets/menu_ui.dart';

/// ─────────────────────────────────────────────────────────────
/// Settings Screen — main-menu styling (glass panels, glossy toggles)
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

  Future<void> _save(GameSettings settings) =>
      context.read<SettingsService>().save(settings);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GameSettings>();
    final ui = MenuMetrics.of(context).contentUi;
    final gap = SizedBox(height: 14 * ui);

    final game = _Section(
      title: 'MATCH CONTROLS',
      icon: Icons.gamepad_rounded,
      children: [
        _Label('Joystick Style',
            settings.dynamicJoystick ? 'DYNAMIC' : 'FIXED'),
        SizedBox(height: 10 * ui),
        MenuSegmented<bool>(
          current: settings.dynamicJoystick,
          segments: const [
            MenuSegment(true, 'DYNAMIC', icon: Icons.touch_app_rounded),
            MenuSegment(false, 'FIXED', icon: Icons.gamepad_rounded),
          ],
          onChanged: (dynamic) {
            settings.dynamicJoystick = dynamic;
            _save(settings);
          },
        ),
        SizedBox(height: 10 * ui),
        const _Hint(
            'Dynamic follows your first touch. Control positions can also be moved while customizing the HUD in a paused match.'),
      ],
    );

    final graphics = _Section(
      title: 'GRAPHICS & PERFORMANCE',
      icon: Icons.speed_rounded,
      children: [
        _Label('Visual Quality', settings.graphicsQuality.name.toUpperCase()),
        SizedBox(height: 10 * ui),
        MenuSegmented<GraphicsQuality>(
          current: settings.graphicsQuality,
          segments: const [
            MenuSegment(GraphicsQuality.low, 'LOW'),
            MenuSegment(GraphicsQuality.medium, 'MEDIUM'),
            MenuSegment(GraphicsQuality.high, 'HIGH'),
          ],
          onChanged: (q) {
            settings.graphicsQuality = q;
            _save(settings);
          },
        ),
        SizedBox(height: 10 * ui),
        _Hint(settings.graphicsQuality == GraphicsQuality.low
            ? 'Smoothest on older phones. Turns off shadows and effects.'
            : settings.graphicsQuality == GraphicsQuality.medium
                ? 'A balance of smooth play and sharp visuals.'
                : 'Every effect on: lighting, shadows and particles.'),
        SizedBox(height: 18 * ui),
        _Label('Frame Rate', '${settings.targetFps} FPS'),
        SizedBox(height: 10 * ui),
        MenuSegmented<int>(
          current: settings.targetFps,
          segments: const [
            MenuSegment(60, '60 FPS  SMOOTH', icon: Icons.bolt_rounded),
            MenuSegment(30, '30 FPS  BATTERY SAVER',
                icon: Icons.battery_saver_rounded),
          ],
          onChanged: (fps) {
            settings.targetFps = fps;
            _save(settings);
          },
        ),
      ],
    );

    final audio = _Section(
      title: 'AUDIO',
      icon: Icons.volume_up_rounded,
      children: [
        _SliderRow(
          label: 'Music Volume',
          icon: Icons.music_note_rounded,
          value: settings.musicVolume,
          onChanged: (v) {
            settings.musicVolume = v;
            try {
              context.read<AudioService>().setMusicVolume(v);
            } catch (_) {}
            _save(settings);
          },
        ),
        SizedBox(height: 8 * ui),
        _SliderRow(
          label: 'Sound Effects',
          icon: Icons.graphic_eq_rounded,
          value: settings.sfxVolume,
          onChanged: (v) {
            settings.sfxVolume = v;
            try {
              context.read<AudioService>().setSfxVolume(v);
            } catch (_) {}
            _save(settings);
          },
        ),
      ],
    );

    final controls = _Section(
      title: 'CONTROLS',
      icon: Icons.gamepad_rounded,
      children: [
        _SliderRow(
          label: 'Joystick Sensitivity',
          icon: Icons.control_camera_rounded,
          value: (settings.joystickSensitivity - 0.5) / 1.5,
          valueText: '${settings.joystickSensitivity.toStringAsFixed(1)}x',
          onChanged: (v) {
            settings.joystickSensitivity = 0.5 + v * 1.5;
            _save(settings);
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4 * ui),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low',
                  style: TextStyle(color: kMenuMuted, fontSize: 11.5 * ui)),
              Text('High',
                  style: TextStyle(color: kMenuMuted, fontSize: 11.5 * ui)),
            ],
          ),
        ),
      ],
    );

    return FadeTransition(
      opacity: _fadeAnim,
      child: MenuScreen(
        title: 'SETTINGS',
        body: LayoutBuilder(builder: (context, c) {
          final twoColumns = c.maxWidth >= 820;
          final content = twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: [game, gap, graphics])),
                    SizedBox(width: 14 * ui),
                    Expanded(child: Column(children: [audio, gap, controls])),
                  ],
                )
              : Column(
                  children: [game, gap, graphics, gap, audio, gap, controls]);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14 * ui, 8 * ui, 14 * ui, 24 * ui),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: content,
              ),
            ),
          );
        }),
      ),
    );
  }

}

// ── Pieces ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return MenuPanel(
      padding: EdgeInsets.all(16 * ui),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuSectionTitle(title, icon: icon),
          SizedBox(height: 14 * ui),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  final String value;
  const _Label(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14.5 * ui,
                fontWeight: FontWeight.w700)),
        Text(value,
            style: TextStyle(
                color: kMenuGold,
                fontSize: 14 * ui,
                fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: kMenuMuted, size: 15 * ui),
        SizedBox(width: 6 * ui),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: kMenuMuted, fontSize: 12.5 * ui, height: 1.3)),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final String? valueText;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: kMenuMuted, size: 18 * ui),
            SizedBox(width: 8 * ui),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5 * ui,
                      fontWeight: FontWeight.w700)),
            ),
            Text(
              valueText ?? '${(value * 100).round()}%',
              style: TextStyle(
                  color: kMenuGold,
                  fontSize: 14 * ui,
                  fontWeight: FontWeight.w900),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 7 * ui,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10 * ui),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 18 * ui),
            activeTrackColor: kMenuGold,
            inactiveTrackColor: kMenuTrack,
            thumbColor: Colors.white,
            overlayColor: kMenuGold.withAlpha(50),
          ),
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ],
    );
  }
}
