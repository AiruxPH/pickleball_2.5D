import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import 'menu_backdrop.dart';
import 'menu/single_slanted_clipper.dart';
import 'menu/shine_sweep.dart';

/// ─────────────────────────────────────────────────────────────
/// Menu UI kit — the main menu's visual language for every other screen:
/// soft court-scene background, dark-navy glass panels, glossy coloured
/// tiles, bold white titles, gold/blue accents.
/// ─────────────────────────────────────────────────────────────

/// Gradient + rim colour for a glossy tile (same palette as the main menu).
class TilePalette {
  final List<Color> colors;
  final Color border;
  const TilePalette(this.colors, this.border);

  /// Palette built from a single accent colour (e.g. a special shot's colour).
  factory TilePalette.from(Color c) => TilePalette(
        [
          Color.lerp(c, Colors.white, 0.18)!,
          c,
          Color.lerp(c, Colors.black, 0.28)!,
        ],
        Color.lerp(c, Colors.white, 0.5)!,
      );

  static const gold = TilePalette(
      [Color(0xFFFFD23F), Color(0xFFFFB300), Color(0xFFF08C00)],
      Color(0xFFFFE48A));
  static const blue = TilePalette(
      [Color(0xFF3B8BFF), Color(0xFF1B5FD9), Color(0xFF1449B5)],
      Color(0xFF7DB2FF));
  static const green = TilePalette(
      [Color(0xFF2ED18A), Color(0xFF14A866), Color(0xFF0B8A52)],
      Color(0xFF7EEDB9));
  static const purple = TilePalette(
      [Color(0xFF8B5CFF), Color(0xFF6A3BE6), Color(0xFF5227C4)],
      Color(0xFFBFA6FF));
  static const red = TilePalette(
      [Color(0xFFFF6B6B), Color(0xFFE53E3E), Color(0xFFB91C1C)],
      Color(0xFFFCA5A5));
  static const slate = TilePalette(
      [Color(0xFF45566F), Color(0xFF2E3D55), Color(0xFF223047)],
      Color(0xFF8A99B1));
}

const kMenuGold = Color(0xFFFFC21A);
const kMenuMuted = Color(0xFFB8C7E0);
const kMenuTrack = Color(0xFF1D3357);

TextStyle menuTitleStyle(double size) => TextStyle(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
      height: 1.1,
      shadows: const [
        Shadow(color: Color(0x59000000), offset: Offset(0, 2), blurRadius: 2)
      ],
    );

/// Press feedback used by every tappable piece: scale, haptic, click sound.
class MenuPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;

  const MenuPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<MenuPressable> createState() => _MenuPressableState();
}

class _MenuPressableState extends State<MenuPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          if (widget.haptic) HapticFeedback.selectionClick();
          try {
            Provider.of<AudioService>(context, listen: false).playButtonClick();
          } catch (_) {}
          widget.onTap!();
        },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: Duration(milliseconds: _down ? 70 : 160),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Soft, out-of-focus version of the menu scene behind sub-screens.
class MenuDimBackdrop extends StatelessWidget {
  const MenuDimBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: kMenuCourtBlue),
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
                sigmaX: 16, sigmaY: 16, tileMode: TileMode.clamp),
            child: Image.asset(
              'assets/images/menu/menu_background.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.low,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x8C0A1F40),
                  Color(0x730C2244),
                  Color(0xA6081830)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen shell: dimmed court scene + menu-style header + body.
class MenuScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final VoidCallback? onBack;

  const MenuScreen({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Scaffold(
      backgroundColor: kMenuCourtBlue,
      body: Stack(
        children: [
          const Positioned.fill(child: MenuDimBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(14 * ui, 10 * ui, 14 * ui, 6 * ui),
                  child: Row(
                    children: [
                      MenuIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      SizedBox(width: 12 * ui),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: menuTitleStyle(24 * ui)),
                            if (subtitle != null) ...[
                              SizedBox(height: 2 * ui),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: kMenuMuted,
                                  fontSize: 12 * ui,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round glass button (back, close, help...).
class MenuIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const MenuIconButton(
      {super.key, required this.icon, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    final s = size * ui;
    return MenuPressable(
      onTap: onTap,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kMenuPanelColor,
          border: Border.all(color: kMenuPanelBorder),
        ),
        child: Icon(icon, color: Colors.white, size: s * 0.55),
      ),
    );
  }
}

/// Dark-navy glass panel.
class MenuPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const MenuPanel(
      {super.key, required this.child, this.padding, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Container(
      padding: padding ?? EdgeInsets.all(16 * ui),
      decoration: BoxDecoration(
        color: kMenuPanelColor,
        borderRadius: BorderRadius.circular(radius * ui),
        border: Border.all(color: kMenuPanelBorder),
      ),
      child: child,
    );
  }
}

/// Section heading: gold icon + white label.
class MenuSectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const MenuSectionTitle(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: kMenuGold, size: 18 * ui),
          SizedBox(width: 8 * ui),
        ],
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13 * ui,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Glossy tile surface used for selected items and buttons with sharp beveled corners.
ShapeDecoration menuTileDecoration(TilePalette p, double radius) => ShapeDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: p.colors,
      ),
      shape: BeveledRectangleBorder(
        side: BorderSide(color: p.border, width: 2),
        borderRadius: BorderRadius.circular(radius),
      ),
      shadows: const [
        BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 4))
      ],
    );

/// Top gloss highlight for glossy tiles with matching beveled chamfer.
class MenuGloss extends StatelessWidget {
  final double radius;
  const MenuGloss({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x38FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00000000),
                Color(0x26000000)
              ],
              stops: [0.0, 0.45, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable athletic card: glossy single-slanted tile when selected, dark-navy glass otherwise.
class MenuSelectTile extends StatelessWidget {
  final bool selected;
  final TilePalette palette;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double titleSize;

  const MenuSelectTile({
    super.key,
    required this.selected,
    required this.palette,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.titleSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    final radius = 14 * ui;
    final accent = palette.colors[1];

    final colors = selected
        ? palette.colors
        : [
            kMenuPanelColor,
            kMenuPanelColor.withAlpha(220),
          ];
    final borderColor = selected ? palette.border : kMenuPanelBorder;

    return MenuPressable(
      onTap: onTap,
      pressedScale: 1.03, // Snappy scale-up matching main menu tiles
      child: ShineSweep(
        autoPeriodic: selected,
        periodicInterval: const Duration(seconds: 6),
        shineColor:
            selected ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF),
        clipper: SingleSlantedClipper(
          angleDegrees: 7.0,
          radius: radius,
          direction: SlantDirection.forward,
        ),
        child: CustomPaint(
          painter: SingleSlantedFramePainter(
            colors: colors,
            borderColor: borderColor,
            borderWidth: selected ? 2.0 : 1.5,
            angleDegrees: 7.0, // Matching 7° athletic slant on right edge only
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
                // Top gloss highlight
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
                      horizontal: 14 * ui, vertical: 10 * ui),
                  child: Row(
                    children: [
                      Container(
                        width: 40 * ui,
                        height: 40 * ui,
                        decoration: ShapeDecoration(
                          shape: BeveledRectangleBorder(
                            borderRadius: BorderRadius.circular(8 * ui),
                          ),
                          color: selected
                              ? Colors.white.withAlpha(46)
                              : accent.withAlpha(46),
                        ),
                        child: Icon(icon,
                            color: selected
                                ? Colors.white
                                : Color.lerp(accent, Colors.white, 0.25),
                            size: 22 * ui),
                      ),
                      SizedBox(width: 12 * ui),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: AppFonts.orbitron,
                                  fontSize: titleSize * ui,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x66000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              SizedBox(height: 3 * ui),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white.withAlpha(230)
                                      : kMenuMuted,
                                  fontSize: 12 * ui,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (selected)
                        Padding(
                          padding: EdgeInsets.only(right: 8 * ui),
                          child: Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22 * ui),
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

/// One option of a [MenuSegmented] control.
class MenuSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  final TilePalette palette;
  const MenuSegment(this.value, this.label,
      {this.icon, this.palette = TilePalette.blue});
}

/// Row of equal buttons, the chosen one glossy in its palette.
class MenuSegmented<T> extends StatelessWidget {
  final List<MenuSegment<T>> segments;
  final T current;
  final ValueChanged<T> onChanged;
  final double height;

  const MenuSegmented({
    super.key,
    required this.segments,
    required this.current,
    required this.onChanged,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    final radius = 10 * ui;
    return Row(
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0) SizedBox(width: 8 * ui),
          Expanded(
            child: MenuPressable(
              onTap: () => onChanged(segments[i].value),
              child: AnimatedContainer(
                key: ValueKey(
                  'menu-segment-${segments[i].label}-${segments[i].value == current}',
                ),
                duration: const Duration(milliseconds: 200),
                height: height * ui,
                decoration: segments[i].value == current
                    ? menuTileDecoration(segments[i].palette, radius)
                    : ShapeDecoration(
                        color: kMenuPanelColor,
                        shape: BeveledRectangleBorder(
                          side: const BorderSide(color: kMenuPanelBorder),
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8 * ui),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (segments[i].icon != null) ...[
                            Icon(segments[i].icon,
                                color: segments[i].value == current
                                    ? Colors.white
                                    : kMenuMuted,
                                size: 18 * ui),
                            SizedBox(width: 6 * ui),
                          ],
                          Text(
                            segments[i].label,
                            style: TextStyle(
                              color: segments[i].value == current
                                  ? Colors.white
                                  : kMenuMuted,
                              fontSize: 13 * ui,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              shadows: segments[i].value == current
                                  ? const [
                                      Shadow(
                                          color: Color(0x59000000),
                                          offset: Offset(0, 1),
                                          blurRadius: 2)
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Big athletic call-to-action button matching the Main Menu PLAY Tile.
class MenuPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final TilePalette palette;
  final double height;

  const MenuPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.palette = TilePalette.gold,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    final radius = 14 * ui;
    final isGold = palette == TilePalette.gold;
    final textColor = isGold ? const Color(0xFF200F00) : Colors.white;

    return MenuPressable(
      onTap: onTap,
      pressedScale: 1.035, // Snappy scale-up matching PlayTile
      child: ShineSweep(
        autoPeriodic: true,
        periodicInterval: const Duration(seconds: 5),
        shineColor: isGold ? const Color(0xFFFFF7D6) : const Color(0x66FFFFFF),
        clipper: SingleSlantedClipper(
          angleDegrees: 7.0,
          radius: radius,
          direction: SlantDirection.forward,
        ),
        child: SizedBox(
          height: height * ui,
          child: CustomPaint(
            painter: SingleSlantedFramePainter(
              colors: palette.colors,
              borderColor: palette.border,
              borderWidth: 2.0,
              angleDegrees: 7.0, // 7° angle on right edge
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
                              Color(0x40FFFFFF),
                              Color(0x05FFFFFF),
                              Color(0x00000000),
                              Color(0x28000000),
                            ],
                            stops: [0.0, 0.45, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * ui),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: textColor, size: 24 * ui),
                              SizedBox(width: 8 * ui),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: AppFonts.orbitron,
                                fontSize: 19 * ui,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(45),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }
}

/// Gold-to-blue progress bar (same as the menu's XP bar).
class MenuProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final List<Color> colors;

  const MenuProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.colors = const [Color(0xFFFFD54A), Color(0xFF4DA3FF)],
  });

  @override
  Widget build(BuildContext context) {
    final ui = MenuMetrics.of(context).contentUi;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * ui / 2),
      child: SizedBox(
        height: height * ui,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF26446F))),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1.0,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(gradient: LinearGradient(colors: colors)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
