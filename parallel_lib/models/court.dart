import '../utils/constants.dart';

/// ─────────────────────────────────────────────────────────────
/// Court model — defines all zones and geometry
/// ─────────────────────────────────────────────────────────────

class Court {
  // ── Dimensions (from CourtDimensions constants) ─────────────
  final double width       = CourtDimensions.width;
  final double length      = CourtDimensions.length;
  final double halfWidth   = CourtDimensions.halfWidth;
  final double halfLength  = CourtDimensions.halfLength;
  final double lineWidth   = CourtDimensions.lineWidth;

  // ── Net ────────────────────────────────────────────────────
  final double netZ        = CourtDimensions.netZ;
  final double netHeight   = CourtDimensions.netHeight;

  // ── Kitchen (Non-Volley Zone) ──────────────────────────────
  /// Kitchen is officially 7 feet (28 units) from the net on each side,
  /// forming a 14-foot (56 units) area around the net.
  /// The Kitchen line is part of the Kitchen.
  final double kitchenDepth = CourtDimensions.kitchenDepth;
  double get playerKitchenNear => netZ;
  double get playerKitchenFar  => netZ + kitchenDepth;

  /// AI-side kitchen: from net (z=0) to z=-kitchenDepth
  double get aiKitchenNear => netZ;
  double get aiKitchenFar  => netZ - kitchenDepth;

  // ── Service Boxes ──────────────────────────────────────────
  // Right service box: X > 0
  // Left service box:  X < 0
  // Depth: from kitchen line to baseline

  // ── Check if a position is inside the court ─────────────────
  bool isInsideCourt(double x, double z) {
    return x.abs() <= halfWidth && z.abs() <= halfLength;
  }

  /// Is position in the kitchen (Non-Volley Zone)?
  /// In official pickleball, the Kitchen line is part of the Kitchen.
  /// If [includeLineWidth] is true, touching the kitchen line counts as in the kitchen.
  bool isInKitchen(double x, double z, {bool includeLineWidth = true}) {
    final lineTol = includeLineWidth ? (lineWidth * 0.5) : 0.0;
    if (z >= 0) {
      // Player side kitchen (0 to 28 + line half-width)
      return z <= (playerKitchenFar + lineTol) && x.abs() <= (halfWidth + lineTol);
    } else {
      // AI side kitchen (0 to -28 - line half-width)
      return z >= (aiKitchenFar - lineTol) && x.abs() <= (halfWidth + lineTol);
    }
  }

  /// Is the ball behind the baseline (out in Z)?
  bool isPastBaseline(double z) {
    return z.abs() > halfLength;
  }

  /// Is the ball past the side lines (out in X)?
  bool isPastSideline(double x) {
    return x.abs() > halfWidth;
  }

  /// Which service box should the ball land in for a valid serve?
  /// Pickleball Rules:
  /// - Server on right side serves diagonally into receiver's right service box.
  /// - Server on left side serves diagonally into receiver's left service box.
  /// - The serve must clear the Kitchen:
  ///   If the serve touches the Kitchen line, it is considered short and is a fault.
  bool isValidServiceBox(double x, double z, bool serverOnRight) {
    if (!isInsideCourt(x, z)) return false;

    // The kitchen line is part of the kitchen. Touching the kitchen line on serve is a fault.
    final lineTol = lineWidth * 0.5;

    if (z > 0) {
      // Ball landing on Player side (AI is serving)
      // Must clear player's kitchen line (must land strictly beyond 28 + lineTol)
      if (z <= (playerKitchenFar + lineTol)) return false;
      // AI serverOnRight -> lands in Player's right service box (x >= 0)
      // AI serverOnLeft  -> lands in Player's left service box (x <= 0)
      if (serverOnRight && x < 0) return false;
      if (!serverOnRight && x > 0) return false;
    } else {
      // Ball landing on AI side (Player is serving)
      // Must clear AI's kitchen line (must land strictly beyond -28 - lineTol)
      if (z >= (aiKitchenFar - lineTol)) return false;
      // Player serverOnRight -> lands in AI's right service box (from camera view, x <= 0)
      // Player serverOnLeft  -> lands in AI's left service box (from camera view, x >= 0)
      if (serverOnRight && x > 0) return false;
      if (!serverOnRight && x < 0) return false;
    }

    return true;
  }
}
