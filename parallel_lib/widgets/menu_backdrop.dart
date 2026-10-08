import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
/// Shared layout rules + scene backdrop for the splash and main menu.
///
/// Both screens place the artwork with the exact same maths, so the splash
/// can cross-fade into the menu while the characters and logo stay put.
/// ─────────────────────────────────────────────────────────────

/// Court colour at the bottom edge of menu_background.jpg.
const kMenuCourtBlue = Color(0xFF3474B3);

/// menu_background.jpg is 1748 x 790.
const double _artAspect = 1748 / 790;

class MenuMetrics {
  final Size size;
  final double bottomInset;

  MenuMetrics(this.size, this.bottomInset);

  factory MenuMetrics.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MenuMetrics(mq.size, mq.padding.bottom);
  }

  bool get landscape => size.width >= size.height;

  /// UI scale from the shorter side: ~1.0 on a 390-430px landscape phone.
  double get ui => (size.shortestSide / 410).clamp(0.82, 1.6);

  /// Gentler scale for content screens (lists, forms) so they don't balloon
  /// on tablets and large windows.
  double get contentUi => ui.clamp(0.85, 1.2);

  double get navHeight => 54 * ui + bottomInset;

  /// Daily challenge bar height plus the gap beneath it.
  double get challengeBlock => 46 * ui + 10 * ui;

  double get tilesWidth => math.min(size.width * 0.5, 620.0 * ui);

  /// Height of the scene art. In landscape the logo (ending ~86% down the
  /// art, right edge at ~1.01 x its height) must stay clear of the daily
  /// challenge bar and the tile column.
  double get heroHeight {
    if (!landscape) return size.height * 0.5;
    final available = size.height - navHeight;
    final tilesLeft = size.width - 14 * ui - tilesWidth;
    return [available, (available - challengeBlock) / 0.86, tilesLeft / 1.03]
        .reduce(math.min);
  }
}

/// Court-blue ground, the scene art and a soft legibility shade.
/// [artScale] allows a gentle zoom (used by the splash intro).
class MenuBackdrop extends StatelessWidget {
  final double artScale;
  final double artOpacity;

  const MenuBackdrop({super.key, this.artScale = 1.0, this.artOpacity = 1.0});

  @override
  Widget build(BuildContext context) {
    final m = MenuMetrics.of(context);
    final h = m.heroHeight;

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: kMenuCourtBlue)),
        Positioned(
          left: 0,
          top: 0,
          width: h * _artAspect,
          height: h,
          child: Opacity(
            opacity: artOpacity,
            child: Transform.scale(
              scale: artScale,
              alignment: const Alignment(-0.4, -0.2),
              child: const _SceneArt(),
            ),
          ),
        ),
        // Soft shade behind the tiles / lower half for legibility
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: m.landscape
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x40061226)
                        ],
                        stops: [0.0, 0.5, 1.0],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0xB3061226)
                        ],
                        stops: [0.0, 0.35, 0.62],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scene art with its right and bottom edges faded into [kMenuCourtBlue].
class _SceneArt extends StatelessWidget {
  const _SceneArt();

  @override
  Widget build(BuildContext context) {
    Widget fade(Widget child, Alignment begin, Alignment end, double from) =>
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: begin,
            end: end,
            colors: const [Color(0xFF000000), Color(0x00000000)],
            stops: [from, 1.0],
          ).createShader(r),
          child: child,
        );

    return fade(
      fade(
        Image.asset(
          'assets/images/menu/menu_background.jpg',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        ),
        Alignment.centerLeft,
        Alignment.centerRight,
        0.86,
      ),
      Alignment.topCenter,
      Alignment.bottomCenter,
      0.9,
    );
  }
}

/// Dark navy panel style shared by menu/splash UI.
const kMenuPanelColor = Color(0xD90C1A33);
const kMenuPanelBorder = Color(0xFF2B4A7A);
