import 'package:flutter/material.dart';
export 'single_slanted_clipper.dart';
export 'shine_sweep.dart';

/// ─────────────────────────────────────────────────────────────
/// AngularFrames & Shape Helpers
/// Provides athletic cut-corner, parallelogram, and trapezoid shapes
/// for high-tech, esports-styled tournament frames.
/// ─────────────────────────────────────────────────────────────

/// Parallelogram slanted badge for active badges, status pills, and tags.
class ParallelogramBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;
  final double skew;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? boxShadow;

  const ParallelogramBadge({
    super.key,
    required this.child,
    required this.color,
    this.borderColor,
    this.skew = -0.22,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: Matrix4.skewX(skew),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
          boxShadow: boxShadow,
        ),
        child: Transform(
          transform: Matrix4.skewX(-skew),
          child: child,
        ),
      ),
    );
  }
}

/// Trapezoid header tab / active indicator
class TrapezoidClipper extends CustomClipper<Path> {
  final double cutWidth;
  final bool inverted;

  const TrapezoidClipper({this.cutWidth = 14.0, this.inverted = false});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (!inverted) {
      // Wider at bottom, narrower at top
      path.moveTo(cutWidth, 0);
      path.lineTo(size.width - cutWidth, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      // Wider at top, narrower at bottom
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width - cutWidth, size.height);
      path.lineTo(cutWidth, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TrapezoidClipper oldClipper) =>
      oldClipper.cutWidth != cutWidth || oldClipper.inverted != inverted;
}

/// 45-degree Chamfered / Cut-Corner Clipper
class ChamferClipper extends CustomClipper<Path> {
  final double cut;
  final bool allCorners;

  const ChamferClipper({this.cut = 12.0, this.allCorners = true});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (allCorners) {
      path.moveTo(cut, 0);
      path.lineTo(size.width - cut, 0);
      path.lineTo(size.width, cut);
      path.lineTo(size.width, size.height - cut);
      path.lineTo(size.width - cut, size.height);
      path.lineTo(cut, size.height);
      path.lineTo(0, size.height - cut);
      path.lineTo(0, cut);
    } else {
      // Diagonal opposite cuts (top-right and bottom-left) for asymmetric cyber feel
      path.moveTo(0, 0);
      path.lineTo(size.width - cut * 1.4, 0);
      path.lineTo(size.width, cut * 1.4);
      path.lineTo(size.width, size.height);
      path.lineTo(cut * 1.4, size.height);
      path.lineTo(0, size.height - cut * 1.4);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ChamferClipper oldClipper) =>
      oldClipper.cut != cut || oldClipper.allCorners != allCorners;
}

/// Beveled corner shape decoration builder for athletic sharp tiles
ShapeDecoration angularCardDecoration({
  required List<Color> colors,
  required Color border,
  double cut = 12.0,
  double borderWidth = 1.8,
  List<BoxShadow>? shadows,
}) {
  return ShapeDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ),
    shape: BeveledRectangleBorder(
      side: BorderSide(color: border, width: borderWidth),
      borderRadius: BorderRadius.circular(cut),
    ),
    shadows: shadows ??
        const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
  );
}

/// Sharp beveled panel decoration for unselected tiles, status panels, and containers.
ShapeDecoration angularPanelDecoration({
  Color color = const Color(0xCC0E1E38),
  Color border = const Color(0xFF1E3A66),
  double cut = 12.0,
  double borderWidth = 1.2,
  List<BoxShadow>? shadows,
}) {
  return ShapeDecoration(
    color: color,
    shape: BeveledRectangleBorder(
      side: BorderSide(color: border, width: borderWidth),
      borderRadius: BorderRadius.circular(cut),
    ),
    shadows: shadows,
  );
}

