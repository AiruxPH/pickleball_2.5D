// Cuts the animation frames out of the character reference sheets in
// Character_sprite/ and packs them into game-ready, transparent atlases:
//
//   assets/images/characters/boy_atlas.png   (+ .json)
//   assets/images/characters/girl_atlas.png  (+ .json)
//
// Every frame is background-keyed, scaled to a consistent body height and
// anchored at the feet so it can be dropped straight onto the court.
//
// Run from the project root:   dart run tool/extract_sprites.dart
// Add --debug to also write build/sprite_debug_*.png for visual checks.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class Section {
  final String name;
  final int x0, y0, x1, y1;
  final int frames;

  /// Standing reference poses drawn at a different size on the sheet are
  /// normalised on their own; every action row shares the walk row's scale
  /// so crouched swings are not blown up.
  final bool ownScale;

  /// With [ownScale]: body height relative to a standing pose (crouched
  /// athletic stances are a little shorter than standing).
  final double heightScale;

  /// Source sheet filename fragment when it differs from the sheet default.
  final String? file;

  /// Remove yellow balls drawn into the frames (the game draws its own).
  final bool removeBall;

  const Section(this.name, this.x0, this.y0, this.x1, this.y1, this.frames,
      {this.ownScale = false, this.heightScale = 1.0, this.file, this.removeBall = false});
}

class Sheet {
  final String id;
  final String fileGlob;
  final List<Section> sections;
  const Sheet(this.id, this.fileGlob, this.sections);
}

// Section rectangles in source-sheet pixels. Each rect sits inside its
// panel, below the heading and above the frame numbers.
//   04_50_01 / 04_50_49: 1254 x 1254 animation sheets
//   05_06_20: 1536 x 1024 swing sheet (Ready, Backswing, Swing, Contact,
//             Follow Through) for both characters
const sheets = [
  Sheet('boy', '04_50_01', [
    Section('idle', 22, 52, 830, 248, 4, ownScale: true), // down, up, left, right
    Section('walk', 22, 332, 615, 478, 4),
    Section('run', 632, 332, 1225, 478, 4),
    Section('jog', 22, 544, 615, 678, 4),
    Section('backpedal', 632, 544, 1225, 678, 4),
    Section('forehand', 632, 746, 1225, 860, 4),
    Section('backhand', 22, 922, 615, 1034, 4),
    Section('celebrate', 22, 1094, 432, 1206, 4),
    Section('hit_left', 18, 176, 762, 414, 5,
        file: '05_06_20', ownScale: true, heightScale: _swingHeight, removeBall: true),
    Section('hit_right', 778, 176, 1530, 414, 5,
        file: '05_06_20', ownScale: true, heightScale: _swingHeight, removeBall: true),
  ]),
  Sheet('girl', '04_50_49', [
    Section('turnaround', 272, 70, 832, 322, 4, ownScale: true), // front, right, back, left
    Section('idle', 22, 418, 398, 560, 4),
    Section('walk', 420, 418, 818, 560, 4),
    Section('run', 836, 418, 1230, 560, 4),
    Section('jog', 22, 632, 398, 772, 4),
    Section('backpedal', 420, 632, 818, 772, 4),
    Section('forehand', 836, 632, 1230, 772, 4),
    Section('backhand', 22, 848, 398, 986, 4),
    Section('celebrate', 836, 850, 1230, 986, 4),
    Section('hit_left', 12, 640, 764, 880, 5,
        file: '05_06_20', ownScale: true, heightScale: _swingHeight, removeBall: true),
    Section('hit_right', 778, 640, 1530, 880, 5,
        file: '05_06_20', ownScale: true, heightScale: _swingHeight, removeBall: true),
  ]),
];

const _swingHeight = 0.95;

// Atlas cell layout (feet anchored at bottom-centre of the cell)
const cellW = 224;
const cellH = 216;
const anchorX = 112;
const anchorY = 202;
const targetBodyH = 150.0; // normalised standing height in atlas pixels

double luma(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

void main(List<String> args) {
  final debug = args.contains('--debug');
  final srcDir = Directory('Character_sprite');
  for (final sheet in sheets) {
    final sources = <String, img.Image>{};
    final debugImgs = <String, img.Image>{};
    img.Image sourceFor(String glob) => sources.putIfAbsent(glob, () {
          final file = srcDir
              .listSync()
              .whereType<File>()
              .firstWhere((f) => f.path.contains(glob));
          return img.decodePng(file.readAsBytesSync())!;
        });
    final maxFrames = sheet.sections.map((s) => s.frames).reduce(math.max);
    final atlas = img.Image(
        width: cellW * maxFrames, height: cellH * sheet.sections.length, numChannels: 4);
    final meta = <String, dynamic>{
      'cellWidth': cellW,
      'cellHeight': cellH,
      'anchorX': anchorX,
      'anchorY': anchorY,
      'bodyHeight': targetBodyH,
      'rows': <String, dynamic>{},
    };

    final extracted = <List<Frame>>[];
    for (final s in sheet.sections) {
      final glob = s.file ?? sheet.fileGlob;
      final src = sourceFor(glob);
      final dbg = debug ? debugImgs.putIfAbsent(glob, () => img.Image.from(src)) : null;
      extracted.add(extractSection(src, s, dbg));
    }
    double medianHeight(List<Frame> fs) {
      final hs = fs.map((f) => f.bodyH).toList()..sort();
      return hs.isEmpty ? targetBodyH : hs[hs.length ~/ 2];
    }

    final walkIdx = sheet.sections.indexWhere((s) => s.name == 'walk');
    final sharedScale = targetBodyH / medianHeight(extracted[walkIdx]);

    for (int row = 0; row < sheet.sections.length; row++) {
      final s = sheet.sections[row];
      final frames = extracted[row];
      if (frames.length != s.frames) {
        stderr.writeln('WARNING ${sheet.id}/${s.name}: found ${frames.length} frames, expected ${s.frames}');
      }
      final scale = s.ownScale
          ? targetBodyH * s.heightScale / medianHeight(frames)
          : sharedScale;

      for (int i = 0; i < frames.length; i++) {
        blitFrame(atlas, frames[i], scale, i * cellW, row * cellH);
      }
      (meta['rows'] as Map)[s.name] = {'row': row, 'frames': frames.length};
      stdout.writeln('${sheet.id}/${s.name}: ${frames.length} frames, scale ${scale.toStringAsFixed(2)}');
    }

    final outBase = 'assets/images/characters/${sheet.id}_atlas';
    File('$outBase.png').writeAsBytesSync(img.encodePng(atlas));
    File('$outBase.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(meta));
    stdout.writeln('Wrote $outBase.png');

    if (debug) {
      Directory('build').createSync(recursive: true);
      debugImgs.forEach((glob, im) => File('build/sprite_debug_${sheet.id}_${glob}_boxes.png')
          .writeAsBytesSync(img.encodePng(im)));
      // Atlas over a magenta checker to reveal any keying mistakes
      final check = img.Image(width: atlas.width, height: atlas.height, numChannels: 4);
      for (final p in check) {
        final c = ((p.x ~/ 8) + (p.y ~/ 8)).isEven;
        p
          ..r = c ? 255 : 200
          ..g = c ? 0 : 60
          ..b = c ? 255 : 200
          ..a = 255;
      }
      img.compositeImage(check, atlas);
      File('build/sprite_debug_${sheet.id}_atlas.png').writeAsBytesSync(img.encodePng(check));
    }
  }
}

class Frame {
  final img.Image rgba; // tight crop with alpha
  final double footX; // anchor in crop coords
  final double footY;
  final double bodyH;
  Frame(this.rgba, this.footX, this.footY, this.bodyH);
}

List<Frame> extractSection(img.Image src, Section s, img.Image? debugImg) {
  final w = s.x1 - s.x0, h = s.y1 - s.y0;
  int idx(int x, int y) => y * w + x;

  final r = List<double>.filled(w * h, 0), g = List<double>.filled(w * h, 0), b = List<double>.filled(w * h, 0);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = src.getPixel(s.x0 + x, s.y0 + y);
      r[idx(x, y)] = p.r.toDouble();
      g[idx(x, y)] = p.g.toDouble();
      b[idx(x, y)] = p.b.toDouble();
    }
  }

  // Background colour = median of the rect border
  final border = <int>[];
  for (int x = 0; x < w; x++) {
    border..add(idx(x, 0))..add(idx(x, h - 1));
  }
  for (int y = 0; y < h; y++) {
    border..add(idx(0, y))..add(idx(w - 1, y));
  }
  double med(List<double> ch) {
    final v = border.map((i) => ch[i]).toList()..sort();
    return v[v.length ~/ 2];
  }

  final bgR = med(r), bgG = med(g), bgB = med(b);
  final bgL = luma(bgR, bgG, bgB);
  final bgBlue = bgB - bgR;

  double distBg(int i) {
    final dr = r[i] - bgR, dg = g[i] - bgG, db = b[i] - bgB;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  // Cast shadows: darker than the background with the same colour cast
  // Near-black shadows lose their colour cast, so below the body line any
  // dark, non-warm pixel counts; higher up (torso, dark clothing) the cast
  // must match the background exactly.
  final feetLine = (h * 0.62).round();
  bool isShadow(int i) {
    final l = luma(r[i], g[i], b[i]);
    if (l >= bgL - 2) return false;
    final blue = b[i] - r[i];
    if (i ~/ w >= feetLine) {
      return r[i] - b[i] < 3 && blue < bgBlue + 9;
    }
    return (blue - bgBlue).abs() < 7 && (r[i] - g[i]).abs() < 9;
  }

  // Region-grow the background from the border. A step is allowed when the
  // pixel is close to the background colour (or is a cast shadow) AND it is
  // smooth relative to its neighbour, so growth stops at character outlines
  // even where dark clothing is close to the background colour.
  final isBg = List<bool>.filled(w * h, false);
  final queue = <int>[];
  for (final i in border) {
    if (!isBg[i] && (distBg(i) < 22 || isShadow(i))) {
      isBg[i] = true;
      queue.add(i);
    }
  }
  var qi = 0;
  while (qi < queue.length) {
    final i = queue[qi++];
    final x = i % w, y = i ~/ w;
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      final nx = x + d[0], ny = y + d[1];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final j = idx(nx, ny);
      if (isBg[j]) continue;
      final dr = r[j] - r[i], dg = g[j] - g[i], db = b[j] - b[i];
      final step = math.sqrt(dr * dr + dg * dg + db * db);
      final shadow = isShadow(j);
      // Cast shadows can have crisp edges, so they may be entered in one step
      if ((distBg(j) < 14 && step < 7) || (shadow && step < 32)) {
        isBg[j] = true;
        queue.add(j);
      }
    }
  }

  // Morphological closing (dilate → erode) of the foreground seals small
  // bites the region-grow took out of dark hair along the outline.
  closeMask(isBg, w, h, 2);
  // Hair crevices can be almost background-coloured; seal wider notches,
  // but only across the head so gaps between arms and body stay open.
  final headOnly = List<bool>.of(isBg);
  closeMask(headOnly, w, h, 6);
  final headLine = (h * 0.45).round();
  for (int i = 0; i < headLine * w; i++) {
    isBg[i] = headOnly[i];
  }

  // Drop drawn balls: saturated yellow, grown a few pixels so their dark
  // perforations and anti-aliased rim go too.
  if (s.removeBall) {
    final ball = List<bool>.filled(w * h, false);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = idx(x, y);
        final yellow = r[i] > 140 && g[i] > 110 && b[i] < g[i] * 0.55 && r[i] - b[i] > 90;
        if (!yellow) continue;
        for (int dy = -4; dy <= 4; dy++) {
          for (int dx = -4; dx <= 4; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h || dx * dx + dy * dy > 16) continue;
            ball[idx(nx, ny)] = true;
          }
        }
      }
    }
    for (int i = 0; i < w * h; i++) {
      if (ball[i]) isBg[i] = true;
    }
  }

  // Connected components of the foreground
  final label = List<int>.filled(w * h, -1);
  final comps = <List<int>>[]; // [minX, minY, maxX, maxY, area]
  for (int i = 0; i < w * h; i++) {
    if (isBg[i] || label[i] >= 0) continue;
    final id = comps.length;
    final c = [w, h, 0, 0, 0];
    final st = [i];
    label[i] = id;
    while (st.isNotEmpty) {
      final k = st.removeLast();
      final x = k % w, y = k ~/ w;
      c[0] = math.min(c[0], x);
      c[1] = math.min(c[1], y);
      c[2] = math.max(c[2], x);
      c[3] = math.max(c[3], y);
      c[4]++;
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final nx = x + d[0], ny = y + d[1];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final j = idx(nx, ny);
        if (!isBg[j] && label[j] < 0) {
          label[j] = id;
          st.add(j);
        }
      }
    }
    comps.add(c);
  }

  // Group components into frames. First join only pieces whose x-ranges
  // (nearly) touch, then repeatedly fold the smallest group into its nearest
  // neighbour (a detached paddle, a hair strand) until the expected frame
  // count remains. This keeps close-packed frames apart.
  final big = <int>[];
  for (int c = 0; c < comps.length; c++) {
    if (comps[c][4] >= 25) big.add(c);
  }
  big.sort((a, b2) => comps[a][0].compareTo(comps[b2][0]));
  final groups = <List<int>>[];
  final gBox = <List<int>>[];
  void mergeBox(List<int> into, List<int> box) {
    into[0] = math.min(into[0], box[0]);
    into[1] = math.min(into[1], box[1]);
    into[2] = math.max(into[2], box[2]);
    into[3] = math.max(into[3], box[3]);
    into[4] += box[4];
  }

  for (final c in big) {
    final box = comps[c];
    if (gBox.isNotEmpty && box[0] <= gBox.last[2] + 2) {
      groups.last.add(c);
      mergeBox(gBox.last, box);
    } else {
      groups.add([c]);
      gBox.add([...box]);
    }
  }

  while (groups.length > s.frames) {
    var smallest = 0;
    for (int i = 1; i < groups.length; i++) {
      if (gBox[i][4] < gBox[smallest][4]) smallest = i;
    }
    final leftGap = smallest > 0 ? gBox[smallest][0] - gBox[smallest - 1][2] : 1 << 30;
    final rightGap =
        smallest < groups.length - 1 ? gBox[smallest + 1][0] - gBox[smallest][2] : 1 << 30;
    final target = leftGap <= rightGap ? smallest - 1 : smallest + 1;
    groups[target].addAll(groups[smallest]);
    mergeBox(gBox[target], gBox[smallest]);
    groups.removeAt(smallest);
    gBox.removeAt(smallest);
  }
  final keep = List.generate(groups.length, (i) => i);

  final frames = <Frame>[];
  for (final gi in keep) {
    final members = groups[gi].toSet();
    final bx = gBox[gi];
    const pad = 2;
    final x0 = math.max(0, bx[0] - pad), y0 = math.max(0, bx[1] - pad);
    final x1 = math.min(w - 1, bx[2] + pad), y1 = math.min(h - 1, bx[3] + pad);
    final crop = img.Image(width: x1 - x0 + 1, height: y1 - y0 + 1, numChannels: 4);

    double sumX = 0, cnt = 0;
    int footY = 0;
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final i = idx(x, y);
        if (isBg[i] || !members.contains(label[i])) continue;

        // Soft edge: pixels touching the background fade by colour distance,
        // and their colour is decontaminated from the background.
        var a = 1.0;
        var touchesBg = false;
        for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          final nx = x + d[0], ny = y + d[1];
          if (nx < 0 || ny < 0 || nx >= w || ny >= h || isBg[idx(nx, ny)]) touchesBg = true;
        }
        if (touchesBg) a = (distBg(i) / 40).clamp(0.35, 1.0);
        double un(double c, double bgc) => ((c - (1 - a) * bgc) / a).clamp(0, 255);

        crop.setPixelRgba(x - x0, y - y0, un(r[i], bgR).round(), un(g[i], bgG).round(),
            un(b[i], bgB).round(), (a * 255).round());

        if (a > 0.5) {
          footY = math.max(footY, y);
          // Horizontal centre from the upper body (ignores a swung paddle)
          if (y < bx[1] + (bx[3] - bx[1]) * 0.55) {
            sumX += x;
            cnt++;
          }
        }
      }
    }
    final cx = cnt > 0 ? sumX / cnt : (bx[0] + bx[2]) / 2;
    frames.add(Frame(crop, cx - x0, (footY - y0).toDouble(), (footY - bx[1]).toDouble()));

    if (debugImg != null) {
      img.drawRect(debugImg,
          x1: s.x0 + x0, y1: s.y0 + y0, x2: s.x0 + x1, y2: s.y0 + y1,
          color: img.ColorRgb8(255, 0, 255));
    }
  }
  if (debugImg != null) {
    img.drawRect(debugImg, x1: s.x0, y1: s.y0, x2: s.x1, y2: s.y1, color: img.ColorRgb8(0, 255, 0));
  }
  return frames;
}

void closeMask(List<bool> isBg, int w, int h, int radius) {
  List<bool> morph(List<bool> fg, bool dilate) {
    final out = List<bool>.filled(w * h, false);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        var v = !dilate;
        for (int dy = -radius; dy <= radius && v == !dilate; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy > radius * radius) continue;
            final nx = x + dx, ny = y + dy;
            final inside = nx >= 0 && ny >= 0 && nx < w && ny < h && fg[ny * w + nx];
            if (dilate && inside) {
              v = true;
              break;
            }
            if (!dilate && !inside) {
              v = false;
              break;
            }
          }
        }
        out[y * w + x] = v;
      }
    }
    return out;
  }

  final fg = [for (final b in isBg) !b];
  final closed = morph(morph(fg, true), false);
  for (int i = 0; i < isBg.length; i++) {
    isBg[i] = !closed[i];
  }
}

void blitFrame(img.Image atlas, Frame f, double scale, int cellX, int cellY) {
  final scaled = img.copyResize(f.rgba,
      width: math.max(1, (f.rgba.width * scale).round()),
      height: math.max(1, (f.rgba.height * scale).round()),
      interpolation: img.Interpolation.cubic);
  final dx = cellX + anchorX - (f.footX * scale).round();
  final dy = cellY + anchorY - (f.footY * scale).round();
  for (final p in scaled) {
    final tx = dx + p.x, ty = dy + p.y;
    if (tx < cellX || ty < cellY || tx >= cellX + cellW || ty >= cellY + cellH) continue;
    if (p.a == 0) continue;
    atlas.setPixelRgba(tx, ty, p.r, p.g, p.b, p.a);
  }
}
