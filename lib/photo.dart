import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Web preview captures point at bundled sample photos instead of files.
bool isAssetPhoto(String path) => path.startsWith('assets/');

Widget capturePhoto(String path, {BoxFit? fit, int? cacheWidth}) {
  if (isAssetPhoto(path)) return Image.asset(path, fit: fit, cacheWidth: cacheWidth);
  return Image.file(File(path), fit: fit, cacheWidth: cacheWidth);
}

Future<Uint8List> capturePhotoBytes(String path) async {
  if (isAssetPhoto(path)) return (await rootBundle.load(path)).buffer.asUint8List();
  return File(path).readAsBytes();
}

Future<void> deletePhoto(String path) async {
  if (kIsWeb || isAssetPhoto(path)) return;
  final f = File(path);
  if (await f.exists()) await f.delete();
}
