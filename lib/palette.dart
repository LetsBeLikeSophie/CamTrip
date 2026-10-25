import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'models.dart';
import 'photo.dart';

class CoverReading {
  final TripPalette palette;
  final bool darkLeft;
  final bool darkRight;
  const CoverReading(this.palette, this.darkLeft, this.darkRight);
}

/// Text on top of [background] should be black when it is light and white
/// when it is dark.
bool isDark(Color background) => background.computeLuminance() <= 0.18;

/// Picks the trip colors from a cover photo, on the device.
///
/// The two strongest hues become two light colors (bands) and two dark
/// colors (buttons). Lightness and saturation are clamped to fixed ranges so
/// any photo gives a calm, readable set.
CoverReading readCover(Uint8List rgba, int width, int height) {
  final bins = List.generate(12, (_) => <int>[0, 0, 0, 0]); // r, g, b, count
  final grey = <int>[0, 0, 0, 0];
  double lumLeft = 0, lumRight = 0;
  var nLeft = 0, nRight = 0;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (rgba[i + 3] < 128) continue;
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      final c = Color.fromARGB(255, r, g, b);
      final hsl = HSLColor.fromColor(c);
      final bin = hsl.saturation > 0.12 && hsl.lightness > 0.08 && hsl.lightness < 0.95
          ? bins[(hsl.hue / 30).floor() % 12]
          : grey;
      bin[0] += r;
      bin[1] += g;
      bin[2] += b;
      bin[3] += 1;

      // Text bands on the trips list sit across the middle of the cover.
      if (y > height * 0.35 && y < height * 0.65) {
        if (x < width * 0.55) {
          lumLeft += c.computeLuminance();
          nLeft++;
        } else if (x > width * 0.75) {
          lumRight += c.computeLuminance();
          nRight++;
        }
      }
    }
  }

  Color avg(List<int> bin) => bin[3] == 0
      ? const Color(0xFF7A869A)
      : Color.fromARGB(255, bin[0] ~/ bin[3], bin[1] ~/ bin[3], bin[2] ~/ bin[3]);

  final ranked = bins.where((b) => b[3] > 0).toList()..sort((a, b) => b[3] - a[3]);
  final first = ranked.isNotEmpty ? avg(ranked[0]) : avg(grey);
  final second = ranked.length > 1 ? avg(ranked[1]) : first;

  // Logo canvas color rules (OKLCH): lights L 0.88–0.93 with C ≤ 0.05,
  // darks L 0.24–0.35 with C ≤ 0.08. The hue stays, only L and C move,
  // which keeps navy text on the lights and ivory text on the darks above
  // 4.5:1 for any photo.
  final a1 = Oklch.of(first), a2 = Oklch.of(second);
  var l1 = a1.l.clamp(0.88, 0.93), l2 = a2.l.clamp(0.88, 0.93);
  if ((l1 - l2).abs() < 0.02) l2 = l1 + 0.02 <= 0.93 ? l1 + 0.02 : l1 - 0.02;
  var d1 = a1.l.clamp(0.24, 0.35), d2 = a2.l.clamp(0.24, 0.35);
  if ((d1 - d2).abs() < 0.02) d2 = d1 + 0.02 <= 0.35 ? d1 + 0.02 : d1 - 0.02;
  final palette = TripPalette(
    Oklch(l1, a1.c.clamp(0.0, 0.05), a1.h).toArgb(),
    Oklch(l2, a2.c.clamp(0.0, 0.05), a2.h).toArgb(),
    Oklch(d1, a1.c.clamp(0.0, 0.08), a1.h).toArgb(),
    Oklch(d2, a2.c.clamp(0.0, 0.08), a2.h).toArgb(),
  );
  return CoverReading(
    palette,
    nLeft == 0 || lumLeft / nLeft <= 0.18,
    nRight == 0 || lumRight / nRight <= 0.18,
  );
}

/// Decodes a small copy of the photo and reads its colors.
Future<CoverReading> readCoverPhoto(String path) async {
  final bytes = await capturePhotoBytes(path);
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final reading = readCover(data!.buffer.asUint8List(), image.width, image.height);
  image.dispose();
  codec.dispose();
  return reading;
}

/// OKLCH color, for moving lightness and chroma while keeping the hue.
class Oklch {
  final double l;
  final double c;
  final double h; // radians
  const Oklch(this.l, this.c, this.h);

  static double _lin(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  static double _gam(double v) => v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  static double _cbrt(double v) => v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();

  factory Oklch.of(Color color) {
    final r = _lin(color.r), g = _lin(color.g), b = _lin(color.b);
    final lm = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final mm = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final sm = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final L = 0.2104542553 * lm + 0.7936177850 * mm - 0.0040720468 * sm;
    final A = 1.9779984951 * lm - 2.4285922050 * mm + 0.4505937099 * sm;
    final B = 0.0259040371 * lm + 0.7827717662 * mm - 0.8086757660 * sm;
    return Oklch(L, math.sqrt(A * A + B * B), math.atan2(B, A));
  }

  int toArgb() {
    final A = c * math.cos(h), B = c * math.sin(h);
    final lm = math.pow(l + 0.3963377774 * A + 0.2158037573 * B, 3).toDouble();
    final mm = math.pow(l - 0.1055613458 * A - 0.0638541728 * B, 3).toDouble();
    final sm = math.pow(l - 0.0894841775 * A - 1.2914855480 * B, 3).toDouble();
    final r = 4.0767416621 * lm - 3.3077115913 * mm + 0.2309699292 * sm;
    final g = -1.2684380046 * lm + 2.6097574011 * mm - 0.3413193965 * sm;
    final b = -0.0041960863 * lm - 0.7034186147 * mm + 1.7076147010 * sm;
    int ch(double v) => (_gam(v.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ch(r), ch(g), ch(b)).toARGB32();
  }
}
