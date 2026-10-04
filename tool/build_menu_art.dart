// Builds the main-menu artwork from the design mock-up
// Character_sprite/main_menu.png (1748 x 900):
//
//   assets/images/menu/menu_background.jpg  scene + characters + logo, with
//                                            every painted UI element removed
//   assets/images/menu/avatar_boy.png        round profile portrait
//   assets/images/menu/play_ball.png         ball artwork for the PLAY tile
//
// The real, working UI is drawn on top by lib/screens/main_menu_screen.dart.
// Run from the project root:  dart run tool/build_menu_art.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Painted UI in the mock-up (x0, y0, x1, y1), padded a little.
const uiRects = [
  [36, 16, 154, 136], // profile portrait
  [148, 26, 400, 106], // profile name bar
  [1162, 20, 1718, 98], // coins, gems, gear, mail
  [896, 160, 1726, 398], // PLAY
  [884, 396, 1312, 566], // MULTIPLAYER
  [1310, 396, 1712, 566], // TOURNAMENT
  [876, 566, 1300, 732], // SHOP
  [1300, 568, 1700, 734], // SETTINGS
  [30, 694, 782, 778], // daily challenge
];
const sceneHeight = 790; // bottom nav bar starts just below

void main() {
  final src = img.decodePng(File('Character_sprite/main_menu.png').readAsBytesSync())!;
  Directory('assets/images/menu').createSync(recursive: true);

  // Crop the small artwork pieces first, from the untouched image
  // Inside the ring painted in the design (the menu draws its own border)
  _circleCrop(src, 95, 76, 46, 160, 'assets/images/menu/avatar_boy.png');
  _circleCrop(src, 1547, 302, 64, 160, 'assets/images/menu/play_ball.png');

  final scene = img.copyCrop(src, x: 0, y: 0, width: src.width, height: sceneHeight);
  _inpaint(scene);
  _skyRowFill(scene, const [
    [36, 16, 154, 136],
    [148, 26, 400, 106],
  ]);
  _extendRightSide(scene);
  File('assets/images/menu/menu_background.jpg')
      .writeAsBytesSync(img.encodeJpg(scene, quality: 86));
  stdout.writeln('Wrote assets/images/menu/ (background, avatar, ball)');
}

/// Round crop with a soft anti-aliased edge.
void _circleCrop(img.Image src, int cx, int cy, int r, int outSize, String path) {
  final crop = img.copyCrop(src, x: cx - r, y: cy - r, width: r * 2, height: r * 2);
  final out = img.copyResize(crop, width: outSize, height: outSize,
      interpolation: img.Interpolation.cubic);
  final rgba = img.Image(width: outSize, height: outSize, numChannels: 4);
  final c = outSize / 2;
  for (final p in out) {
    final d = math.sqrt(math.pow(p.x + 0.5 - c, 2) + math.pow(p.y + 0.5 - c, 2));
    final a = ((c - d) / 1.5).clamp(0.0, 1.0);
    rgba.setPixelRgba(p.x, p.y, p.r, p.g, p.b, (a * 255).round());
  }
  File(path).writeAsBytesSync(img.encodePng(rgba));
}

/// Fills the UI rectangles with smooth background, like an out-of-focus
/// continuation of the scene: coarse membrane (diffusion) fill from the
/// surrounding pixels, upsampled, with light grain and a feathered seam.
void _inpaint(img.Image im) {
  final w = im.width, h = im.height;
  final mask = List<bool>.filled(w * h, false);
  for (final r in uiRects) {
    for (int y = math.max(0, r[1]); y < math.min(h, r[3]); y++) {
      for (int x = math.max(0, r[0]); x < math.min(w, r[2]); x++) {
        mask[y * w + x] = true;
      }
    }
  }

  // 1. Coarse grid of known colours
  const f = 8;
  final gw = (w / f).ceil(), gh = (h / f).ceil();
  final gr = List<double>.filled(gw * gh, 0), gg = List<double>.filled(gw * gh, 0);
  final gb = List<double>.filled(gw * gh, 0);
  final known = List<bool>.filled(gw * gh, false);
  for (int by = 0; by < gh; by++) {
    for (int bx = 0; bx < gw; bx++) {
      double r = 0, g = 0, b = 0;
      int n = 0, total = 0;
      for (int y = by * f; y < math.min(h, by * f + f); y++) {
        for (int x = bx * f; x < math.min(w, bx * f + f); x++) {
          total++;
          if (mask[y * w + x]) continue;
          final p = im.getPixel(x, y);
          r += p.r;
          g += p.g;
          b += p.b;
          n++;
        }
      }
      final i = by * gw + bx;
      if (n > total * 0.6) {
        gr[i] = r / n;
        gg[i] = g / n;
        gb[i] = b / n;
        known[i] = true;
      }
    }
  }

  // 2. Diffuse into unknown cells (Laplace / membrane fill)
  for (int i = 0; i < gw * gh; i++) {
    if (!known[i]) {
      gr[i] = 40;
      gg[i] = 70;
      gb[i] = 120;
    }
  }
  for (int iter = 0; iter < 900; iter++) {
    for (int by = 0; by < gh; by++) {
      for (int bx = 0; bx < gw; bx++) {
        final i = by * gw + bx;
        if (known[i]) continue;
        double r = 0, g = 0, b = 0;
        int n = 0;
        for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          final nx = bx + d[0], ny = by + d[1];
          if (nx < 0 || ny < 0 || nx >= gw || ny >= gh) continue;
          final j = ny * gw + nx;
          r += gr[j];
          g += gg[j];
          b += gb[j];
          n++;
        }
        gr[i] = r / n;
        gg[i] = g / n;
        gb[i] = b / n;
      }
    }
  }

  // 3. Bilinear upsample into the masked pixels, with a little grain
  double sample(List<double> ch, double fx, double fy) {
    final x0 = fx.floor().clamp(0, gw - 1), y0 = fy.floor().clamp(0, gh - 1);
    final x1 = math.min(gw - 1, x0 + 1), y1 = math.min(gh - 1, y0 + 1);
    final tx = (fx - x0).clamp(0.0, 1.0), ty = (fy - y0).clamp(0.0, 1.0);
    final a = ch[y0 * gw + x0] * (1 - tx) + ch[y0 * gw + x1] * tx;
    final b = ch[y1 * gw + x0] * (1 - tx) + ch[y1 * gw + x1] * tx;
    return a * (1 - ty) + b * ty;
  }

  final rng = math.Random(7);
  final filled = img.Image.from(im);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (!mask[y * w + x]) continue;
      final fx = (x + 0.5) / f - 0.5, fy = (y + 0.5) / f - 0.5;
      final n = (rng.nextDouble() - 0.5) * 5;
      filled.setPixelRgb(
        x,
        y,
        (sample(gr, fx, fy) + n).clamp(0, 255).round(),
        (sample(gg, fx, fy) + n).clamp(0, 255).round(),
        (sample(gb, fx, fy) + n).clamp(0, 255).round(),
      );
    }
  }

  // 4. Feather the seam: blend a band just inside each hole toward a local blur
  const band = 34;
  final blurred = img.gaussianBlur(img.Image.from(filled), radius: 16);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (!mask[y * w + x]) {
        im.setPixel(x, y, filled.getPixel(x, y));
        continue;
      }
      // distance to the nearest unmasked pixel (cheap axis search)
      int dist = band;
      for (int d = 1; d < band; d++) {
        final hit = (x - d >= 0 && !mask[y * w + x - d]) ||
            (x + d < w && !mask[y * w + x + d]) ||
            (y - d >= 0 && !mask[(y - d) * w + x]) ||
            (y + d < h && !mask[(y + d) * w + x]);
        if (hit) {
          dist = d;
          break;
        }
      }
      final t = dist / band; // 0 at the seam → 1 deep inside
      final a = filled.getPixel(x, y), b = blurred.getPixel(x, y);
      final k = 1 - t; // more blur near the seam
      im.setPixelRgb(
        x,
        y,
        (a.r * (1 - k) + b.r * k).round(),
        (a.g * (1 - k) + b.g * k).round(),
        (a.b * (1 - k) + b.b * k).round(),
      );
    }
  }
}

/// Replaces everything right of the clean artwork (where the design had its
/// painted buttons) with a smooth continuation of the scene: each row takes
/// the real colour at the art's right edge, smoothed vertically into a soft
/// sky -> trees -> court gradient, with a short blend so the fence and court
/// dissolve into it. No smeared fill, no patch edges.
void _extendRightSide(img.Image im) {
  const blendFrom = 700; // wide, soft transition (the flying ball stays sharp)
  const sampleFrom = 846; // edge colours are taken right of the ball
  const artEdge = 882; // the PLAY button starts at ~896 in the design
  final w = im.width, h = im.height;

  // 1. Edge colour per row
  final r = List<double>.filled(h, 0), g = List<double>.filled(h, 0);
  final b = List<double>.filled(h, 0);
  for (int y = 0; y < h; y++) {
    double sr = 0, sg = 0, sb = 0;
    for (int x = sampleFrom; x < artEdge; x++) {
      final p = im.getPixel(x, y);
      sr += p.r;
      sg += p.g;
      sb += p.b;
    }
    const n = artEdge - sampleFrom;
    r[y] = sr / n;
    g[y] = sg / n;
    b[y] = sb / n;
  }

  // 2. Smooth vertically (three box passes ~ gaussian) so fence posts and
  //    net lines don't turn into horizontal streaks
  List<double> smooth(List<double> v) {
    var cur = v;
    for (int pass = 0; pass < 3; pass++) {
      const k = 95; // broad: sky -> court, no bands
      final out = List<double>.filled(h, 0);
      for (int y = 0; y < h; y++) {
        double sum = 0;
        int cnt = 0;
        for (int d = -k; d <= k; d++) {
          final yy = (y + d).clamp(0, h - 1);
          sum += cur[yy];
          cnt++;
        }
        out[y] = sum / cnt;
      }
      cur = out;
    }
    return cur;
  }

  final sr = smooth(r), sg = smooth(g), sb = smooth(b);

  // 3. Blend the art into the gradient, then fill to the right edge with
  //    light grain (prevents JPEG banding) and a gentle darkening
  // The last strip of art goes soft (out of focus) before meeting the gradient
  final soft = img.gaussianBlur(img.Image.from(im), radius: 10);
  final rng = math.Random(11);
  for (int y = 0; y < h; y++) {
    for (int x = blendFrom; x < w; x++) {
      final shade = 1.0 - 0.10 * ((x - artEdge) / (w - artEdge)).clamp(0.0, 1.0);
      final grain = (rng.nextDouble() - 0.5) * 3;
      final er = sr[y] * shade + grain, eg = sg[y] * shade + grain, eb = sb[y] * shade + grain;
      if (x < artEdge) {
        // Rows crossed by the logo (its brush tail reaches x ~800 around
        // y 400-560) start the transition further right, easing in and out
        // over the rows so no edge appears.
        final start = blendFrom + 108 * _pulse(y.toDouble(), 330, 410, 560, 640);
        final t0 = ((x - start) / (artEdge - start)).clamp(0.0, 1.0);
        // Keep the flying ball (centre 812,300; r ~43) in focus
        final bx = x - 812.0, by = y - 300.0;
        final keep = ((math.sqrt(bx * bx + by * by) - 46) / 8).clamp(0.0, 1.0);
        final t = t0 * t0 * (3 - 2 * t0) * keep;
        // sharp -> out-of-focus in the first half, -> gradient in the second
        final f = (t0 * 2).clamp(0.0, 1.0) * keep;
        final p = im.getPixel(x, y), q = soft.getPixel(x, y);
        final ar = p.r * (1 - f) + q.r * f;
        final ag = p.g * (1 - f) + q.g * f;
        final ab = p.b * (1 - f) + q.b * f;
        im.setPixelRgb(
          x,
          y,
          (ar * (1 - t) + er * t).round().clamp(0, 255),
          (ag * (1 - t) + eg * t).round().clamp(0, 255),
          (ab * (1 - t) + eb * t).round().clamp(0, 255),
        );
      } else {
        im.setPixelRgb(x, y, er.round().clamp(0, 255), eg.round().clamp(0, 255),
            eb.round().clamp(0, 255));
      }
    }
  }
}

/// The profile badge sat on clear sky with clouds around its edges. Each
/// hidden pixel starts as clear sky (sampled from the same row just right of
/// the badge), and the real pixels at the hole's edges fade in only close to
/// those edges, so nearby clouds continue a little way and then dissolve.
void _skyRowFill(img.Image im, List<List<int>> rects) {
  final w = im.width, h = im.height;
  bool masked(int x, int y) =>
      rects.any((r) => x >= r[0] && x < r[2] && y >= r[1] && y < r[3]);

  List<double> px(int x, int y) {
    // 3-pixel average for a steadier boundary sample
    double r = 0, g = 0, b = 0;
    for (int d = -1; d <= 1; d++) {
      final p = im.getPixel(x.clamp(0, w - 1), (y + d).clamp(0, h - 1));
      r += p.r;
      g += p.g;
      b += p.b;
    }
    return [r / 3, g / 3, b / 3];
  }

  final minX = rects.map((r) => r[0]).reduce(math.min);
  final maxX = rects.map((r) => r[2]).reduce(math.max);
  final minY = rects.map((r) => r[1]).reduce(math.min);
  final maxY = rects.map((r) => r[3]).reduce(math.max);

  final fill = <int, List<double>>{};
  for (int y = minY; y < maxY; y++) {
    for (int x = minX; x < maxX; x++) {
      if (!masked(x, y)) continue;
      // horizontal span
      var xa = x, xb = x;
      while (xa > 0 && masked(xa - 1, y)) {
        xa--;
      }
      while (xb < w - 1 && masked(xb + 1, y)) {
        xb++;
      }
      // vertical span
      var ya = y, yb = y;
      while (ya > 0 && masked(x, ya - 1)) {
        ya--;
      }
      while (yb < h - 1 && masked(x, yb + 1)) {
        yb++;
      }
      final sky = [0.0, 0.0, 0.0];
      for (int sx = 412; sx < 428; sx += 4) {
        final p = px(sx, y);
        for (int c = 0; c < 3; c++) {
          sky[c] += p[c] / 4;
        }
      }
      // Edge samples, strong only within ~10 px of their edge
      final edges = <List<double>>[];
      final weights = <double>[];
      void edge(List<double> colour, int dist) {
        edges.add(colour);
        weights.add(8 * math.exp(-dist / 11));
      }

      edge(px(xa - 1, y), x - xa);
      edge(px(xb + 1, y), xb - x);
      edge(px(x, ya - 1), y - ya);
      edge(px(x, yb + 1), yb - y);
      final total = 1 + weights.reduce((a, b) => a + b);
      fill[y * w + x] = [
        for (int c = 0; c < 3; c++)
          (sky[c] + [for (int k = 0; k < 4; k++) edges[k][c] * weights[k]]
                      .reduce((a, b) => a + b)) /
              total,
      ];
    }
  }

  // Light smoothing inside the hole, then grain against JPEG banding
  final rng = math.Random(5);
  fill.forEach((i, _) {
    final x = i % w, y = i ~/ w;
    double r = 0, g = 0, b = 0;
    int n = 0;
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx += 2) {
        final v = fill[(y + dy) * w + (x + dx)];
        if (v == null) continue;
        r += v[0];
        g += v[1];
        b += v[2];
        n++;
      }
    }
    final grain = (rng.nextDouble() - 0.5) * 3;
    im.setPixelRgb(x, y, (r / n + grain).round().clamp(0, 255),
        (g / n + grain).round().clamp(0, 255), (b / n + grain).round().clamp(0, 255));
  });

  // Melt the straight seams: blur a narrow band on both sides of the border
  const band = 7;
  final soft = img.gaussianBlur(img.Image.from(im), radius: 5);
  for (int y = math.max(0, minY - band); y < math.min(h, maxY + band); y++) {
    for (int x = math.max(0, minX - band); x < math.min(w, maxX + band); x++) {
      final inside = masked(x, y);
      int d = band;
      for (int k = 1; k < band; k++) {
        if (masked(x - k, y) != inside ||
            masked(x + k, y) != inside ||
            masked(x, y - k) != inside ||
            masked(x, y + k) != inside) {
          d = k;
          break;
        }
      }
      if (d >= band) continue;
      final k = 1 - d / band; // strongest right on the seam
      final a = im.getPixel(x, y), b = soft.getPixel(x, y);
      im.setPixelRgb(
        x,
        y,
        (a.r * (1 - k) + b.r * k).round(),
        (a.g * (1 - k) + b.g * k).round(),
        (a.b * (1 - k) + b.b * k).round(),
      );
    }
  }
}

/// 0 outside [a, d], 1 inside [b, c], smooth ramps between.
double _pulse(double v, double a, double b, double c, double d) {
  double ss(double t) {
    final k = t.clamp(0.0, 1.0);
    return k * k * (3 - 2 * k);
  }

  if (v <= b) return ss((v - a) / (b - a));
  if (v >= c) return ss((d - v) / (d - c));
  return 1.0;
}
