import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';
import 'photo.dart';
import 'ui.dart';

/// The photo as taken. While the user presses on it, the photo dims and
/// each block's translation sits on a paper-colored strip at the same spot
/// (like a filter before/after button). Letting go shows the original.
class HoldPhoto extends StatefulWidget {
  final Capture capture;
  const HoldPhoto({super.key, required this.capture});

  @override
  State<HoldPhoto> createState() => _HoldPhotoState();
}

class _HoldPhotoState extends State<HoldPhoto> {
  Size? _size;
  bool _missing = false;
  bool _hold = false;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    try {
      final bytes = await capturePhotoBytes(widget.capture.imagePath);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      if (mounted) setState(() => _size = size);
    } catch (e) {
      debugPrint('CamTrip: could not open photo: $e');
      if (mounted) setState(() => _missing = true);
    }
  }

  void _set(bool v) {
    if (_hold != v) setState(() => _hold = v);
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final c = widget.capture;
    final Widget photo;
    if (size == null) {
      photo = AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(
          child: Text(_missing ? '사진을 열 수 없어요' : '', style: body(13, color: C.ivory)),
        ),
      );
    } else {
      photo = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _hold ? 0.45 : 1,
                      child: ImageFiltered(
                        enabled: _hold,
                        imageFilter: ui.ImageFilter.blur(sigmaX: size.width / 300, sigmaY: size.width / 300),
                        child: capturePhoto(c.imagePath, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  if (_hold)
                    for (final b in c.blocks)
                      Positioned(
                        left: b.left,
                        top: b.top,
                        width: b.width,
                        height: b.height,
                        child: Container(
                          color: C.tape,
                          padding: EdgeInsets.symmetric(horizontal: b.height * 0.12),
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: b.width * 1.6),
                              child: Text(
                                b.translated,
                                style: body((size.width / 26).clamp(14.0, 90.0), weight: FontWeight.w500, height: 1.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: '누르고 있는 동안 번역이 보여요',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onLongPressStart: (_) => _set(true),
        onLongPressEnd: (_) => _set(false),
        child: ColoredBox(
          color: C.photoDark,
          child: Column(
            children: [
              Center(child: photo),
              Container(
                height: 40,
                color: C.navy.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_hold ? '번역 보는 중' : '사진을 누르고 있으면 번역',
                          style: body(13, color: C.ivory)),
                    ),
                    Text(_hold ? '떼면 원본' : 'HOLD', style: mono(11, color: C.ivory.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
