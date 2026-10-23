
import 'package:flutter/material.dart';

import '../main.dart' show ink, muted;
import '../models.dart';
import '../photo.dart';
import '../store.dart';
import 'result_screen.dart';

/// S06 여행 목록.
class TripsScreen extends StatelessWidget {
  final AppStore store;
  const TripsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trips = [...store.trips]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              '여행',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
            ),
            const SizedBox(height: 16),
            if (trips.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  '번역을 하면 여행이 자동으로 만들어져요.',
                  style: TextStyle(color: muted),
                ),
              ),
            for (final t in trips) ...[
              const Divider(),
              InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TripDetailScreen(store: store, trip: t),
                )),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${_d(t.startAt)} — ${_d(t.lastAt)} · 번역 ${store.capturesOf(t).length}개',
                              style: const TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),
            ],
            if (trips.isNotEmpty) const Divider(),
          ],
        );
      },
    );
  }
}

String _d(DateTime d) => '${d.month}.${d.day}';

/// S07 여행 상세 (prototype: photos only; expenses come later).
class TripDetailScreen extends StatefulWidget {
  final AppStore store;
  final Trip trip;
  const TripDetailScreen({super.key, required this.store, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  String? _filter;

  Future<void> _edit() async {
    final country = TextEditingController(text: widget.trip.country);
    final city = TextEditingController(text: widget.trip.city);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('여행 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: country, decoration: const InputDecoration(labelText: '나라')),
            const SizedBox(height: 8),
            TextField(controller: city, decoration: const InputDecoration(labelText: '도시')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소', style: TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장', style: TextStyle(color: ink))),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.updateTrip(widget.trip, country: country.text.trim(), city: city.text.trim());
    }
    // Dispose after the dialog route has fully closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      country.dispose();
      city.dispose();
    });
  }

  Future<void> _deleteTrip() async {
    final count = widget.store.capturesOf(widget.trip).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('이 여행을 지울까요?'),
        content: Text('번역 $count개와 사진이 모두 지워져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소', style: TextStyle(color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기', style: TextStyle(color: ink))),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteTrip(widget.trip);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // The trip disappears when its last translation is deleted.
        if (!widget.store.trips.any((t) => t.id == widget.trip.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold();
        }
        final all = widget.store.capturesOf(widget.trip);
        final list = _filter == null ? all : all.where((c) => c.category == _filter).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.trip.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(tooltip: '여행 정보 수정', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
              IconButton(tooltip: '여행 지우기', onPressed: _deleteTrip, icon: const Icon(Icons.delete_outline)),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _filterChip('전체', null),
                    for (final cat in categories) _filterChip(cat, cat),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('아직 없어요', style: TextStyle(color: muted)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return InkWell(
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ResultScreen(store: widget.store, capture: c),
                              ));
                              // Deleting the last translation removes the trip too.
                              if (mounted && !widget.store.trips.any((t) => t.id == widget.trip.id)) {
                                Navigator.of(this.context).pop();
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                capturePhoto(c.imagePath, fit: BoxFit.cover, cacheWidth: 400),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Text(
                                      '${c.category} · ${c.summary}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: ink),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String? value) {
    final on = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.only(right: 18),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? ink : muted,
                decoration: on ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
