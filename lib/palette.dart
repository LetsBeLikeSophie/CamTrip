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

  int tone(Color base, double lightness, double maxSat) {
    final h = HSLColor.fromColor(base);
    final s = h.saturation.clamp(0.0, maxSat);
    return HSLColor.fromAHSL(1, h.hue, s, lightness).toColor().toARGB32();
  }

  final palette = TripPalette(
    tone(first, 0.88, 0.35),
    tone(second, 0.91, 0.30),
    tone(first, 0.20, 0.45),
    tone(second, 0.26, 0.40),
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
