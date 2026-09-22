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

  // ── Net ────────────────────────────────────────────────────
  final double netZ        = CourtDimensions.netZ;
  final double netHeight   = CourtDimensions.netHeight;

  // ── Kitchen (Non-Volley Zone) ──────────────────────────────
  /// Player-side kitchen: from net (z=0) to z=+kitchenDepth
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

  /// Is position in the kitchen (non-volley zone)?
  bool isInKitchen(double x, double z) {
    if (z >= 0) {
      // Player side kitchen
      return z <= playerKitchenFar && x.abs() <= halfWidth;
    } else {
      // AI side kitchen
      return z >= aiKitchenFar && x.abs() <= halfWidth;
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
  /// Pickleball Diagonal Rule:
  /// - Server on right side serves diagonally into receiver's right service box.
  /// - Server on left side serves diagonally into receiver's left service box.
  /// - Ball MUST clear the net AND clear the Non-Volley Zone (kitchen).
  bool isValidServiceBox(double x, double z, bool serverOnRight) {
    if (!isInsideCourt(x, z)) return false;

    if (z > 0) {
      // Ball landing on Player side (AI is serving)
      // Must be past player's kitchen line (z > 28)
      if (z <= playerKitchenFar) return false;
      // AI serverOnRight -> lands in Player's right service box (x >= 0)
      // AI serverOnLeft  -> lands in Player's left service box (x <= 0)
      if (serverOnRight && x < 0) return false;
      if (!serverOnRight && x > 0) return false;
    } else {
      // Ball landing on AI side (Player is serving)
      // Must be past AI's kitchen line (z < -28)
      if (z >= aiKitchenFar) return false;
      // Player serverOnRight -> lands in AI's right service box (from camera view, x <= 0)
      // Player serverOnLeft  -> lands in AI's left service box (from camera view, x >= 0)
      if (serverOnRight && x > 0) return false;
      if (!serverOnRight && x < 0) return false;
    }

    return true;
  }
}
