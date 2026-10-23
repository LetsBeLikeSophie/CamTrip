import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../main.dart' show ink, muted;
import '../models.dart';
import '../photo.dart';
import '../store.dart';

/// S03 번역 결과. Overlays the translation on the photo. Saved automatically.
class ResultScreen extends StatefulWidget {
  final AppStore store;
  final Capture capture;
  const ResultScreen({super.key, required this.store, required this.capture});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showTranslated = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  bool _imageMissing = false;

  Future<void> _loadSize() async {
    try {
      final bytes = await capturePhotoBytes(widget.capture.imagePath);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() => _imageSize = size);
    } catch (e) {
      debugPrint('CamTrip: could not open photo: $e');
      if (mounted) setState(() => _imageMissing = true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('이 번역을 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소', style: TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기', style: TextStyle(color: ink))),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteCapture(widget.capture);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.capture;
    return Scaffold(
      appBar: AppBar(
        title: const Text('번역 결과', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: '지우기',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          _photo(c),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check, size: 16, color: muted),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('여행에 자동 저장됐어요', style: TextStyle(fontSize: 12, color: muted)),
              ),
              TextButton(
                onPressed: () => setState(() => _showTranslated = !_showTranslated),
                child: Text(
                  _showTranslated ? '원문 보기' : '번역 보기',
                  style: const TextStyle(color: ink, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('카테고리', style: TextStyle(fontSize: 13, color: muted)),
          Wrap(
            spacing: 16,
            children: [
              for (final cat in categories)
                InkWell(
                  onTap: () async {
                    await widget.store.setCategory(c, cat);
                    if (mounted) setState(() {});
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      widthFactor: 1,
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: c.category == cat ? FontWeight.w600 : FontWeight.w400,
                          color: c.category == cat ? ink : muted,
                          decoration: c.category == cat ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          for (final b in c.blocks) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.translated, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 4),
                  Text(b.source, style: const TextStyle(fontSize: 13, color: muted, height: 1.4)),
                ],
              ),
            ),
            const Divider(),
          ],
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: OutlinedButton(onPressed: null, child: Text('사진에 질문 (곧)'))),
              SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: null, child: Text('답장 카드 (곧)'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photo(Capture c) {
    final size = _imageSize;
    if (size == null) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(
          color: const Color(0xFFEFEFEF),
          child: _imageMissing
              ? const Center(child: Text('사진을 열 수 없어요', style: TextStyle(color: muted)))
              : null,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                Positioned.fill(child: capturePhoto(c.imagePath, fit: BoxFit.fill)),
                if (_showTranslated)
                  for (final b in c.blocks)
                    Positioned(
                      left: b.left,
                      top: b.top,
                      width: b.width,
                      height: b.height,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.94),
                        padding: EdgeInsets.all(b.height * 0.04),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: b.width),
                            child: Text(
                              b.translated,
                              style: TextStyle(
                                color: ink,
                                fontSize: (size.width / 28).clamp(14.0, 80.0),
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
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
}
