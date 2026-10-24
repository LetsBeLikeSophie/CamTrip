import 'package:flutter/material.dart';

import '../models.dart';
import '../money.dart';
import '../photo.dart';
import '../store.dart';
import '../ui.dart';
import 'receipt_screen.dart';
import 'settings_screen.dart';
import 'translate_screen.dart';

/// Every trip as a band with its cover photo behind it. Text is black or
/// white depending on how bright the photo is under it.
class TripsScreen extends StatelessWidget {
  final AppStore store;
  const TripsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trips = [...store.trips]..sort((a, b) => b.lastAt.compareTo(a.lastAt));
        final days = trips.fold<int>(0, (n, t) => n + t.dayOf(t.lastAt));
        final countries = trips.map((t) => t.country).where((c) => c.isNotEmpty).toSet().length;
        final translated = store.captures.where((c) => !c.isReceipt).length;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(
                  leading: const BackArrow(),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
                      ),
                      child: Text('설정', style: body(13)),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SerifTitle('다녀온 곳', size: 40),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                        child: Text(
                          trips.isEmpty
                              ? '사진을 찍으면 여행이 자동으로 만들어져요.'
                              : '$days일, ${countries == 0 ? 1 : countries}개 나라. 번역 $translated번.',
                          style: body(14, color: C.sub),
                        ),
                      ),
                      Container(height: 1, color: C.navy),
                      for (final t in trips) _TripBand(store: store, trip: t),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TripBand extends StatelessWidget {
  final AppStore store;
  final Trip trip;
  const _TripBand({required this.store, required this.trip});

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverPath;
    final current = store.currentTrip?.id == trip.id;
    final leftFg = cover == null ? textOn(trip.dark1) : (trip.coverDarkLeft ? Colors.white : const Color(0xFF111111));
    final rightFg = cover == null ? textOn(trip.dark1) : (trip.coverDarkRight ? Colors.white : const Color(0xFF111111));
    final count = store.capturesOf(trip).where((c) => !c.isReceipt).length;
    final spent = store.spentOf(trip);
    return Semantics(
      button: true,
      label: '${trip.place} 여행',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripDetailScreen(store: store, trip: trip)),
        ),
        child: Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              cover == null ? ColoredBox(color: trip.dark1) : capturePhoto(cover, fit: BoxFit.cover, cacheWidth: 900),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.place.isEmpty ? '여행' : trip.place, style: serif(19, color: leftFg)),
                          Text(
                            [
                              current ? '여행 중' : '다녀옴',
                              '번역 $count',
                              if (spent > 0) formatMoney(spent, currencyFor(trip.lang)),
                            ].join(' · '),
                            style: body(12, color: leftFg.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      current ? '${md(trip.startAt)} —' : '${trip.startAt.year}.${trip.startAt.month.toString().padLeft(2, '0')}',
                      style: mono(12, color: rightFg),
                    ),
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

/// One trip: every photo, plus edit and delete.
class TripDetailScreen extends StatelessWidget {
  final AppStore store;
  final Trip trip;
  const TripDetailScreen({super.key, required this.store, required this.trip});

  Future<void> _edit(BuildContext context) async {
    final country = TextEditingController(text: trip.country);
    final city = TextEditingController(text: trip.city);
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: body(13, color: C.sub),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.line)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.navy)),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.ivory,
        surfaceTintColor: C.ivory,
        shape: const RoundedRectangleBorder(),
        title: Text('여행 정보', style: serif(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: country, style: body(16), decoration: deco('나라')),
            TextField(controller: city, style: body(16), decoration: deco('도시')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: body(14, color: C.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('저장', style: body(14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.updateTrip(trip, country: country.text.trim(), city: city.text.trim());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      country.dispose();
      city.dispose();
    });
  }

  Future<void> _delete(BuildContext context) async {
    final n = store.capturesOf(trip).length + store.memosOf(trip).length;
    final ok = await confirm(context, '이 여행을 지울까요?', '기록 $n개와 사진이 모두 지워져요.');
    if (ok != true) return;
    await store.deleteTrip(trip);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.trips.any((t) => t.id == trip.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).pop();
          });
          return const Scaffold();
        }
        final photos = store.capturesOf(trip);
        final memos = store.memosOf(trip);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(
                  leading: const BackArrow(),
                  actions: [
                    IconButton(
                      tooltip: '여행 정보 고치기',
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_outlined, color: C.navy),
                    ),
                    IconButton(
                      tooltip: '여행 지우기',
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete_outline, color: C.navy),
                    ),
                  ],
                ),
                ContextBand(
                  label: '${trip.place} · ${md(trip.startAt)} — ${md(trip.lastAt)}',
                  color: trip.light1,
                  trailing: Text(formatMoney(store.spentOf(trip), currencyFor(trip.lang)),
                      style: mono(12, color: textOn(trip.light1))),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      SerifTitle(trip.name, size: 32),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, i) {
                          final c = photos[i];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => c.isReceipt
                                  ? ReceiptScreen(store: store, capture: c)
                                  : TranslateScreen(store: store, capture: c),
                            )),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                capturePhoto(c.imagePath, fit: BoxFit.cover, cacheWidth: 400),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    color: C.ivory,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Text(
                                      c.isReceipt
                                          ? '경비 · ${c.amount == null ? '' : formatMoney(c.amount!, c.currency)}'
                                          : c.summary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: body(11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (memos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                          child: Text('음성 메모', style: serif(20)),
                        ),
                        for (final m in memos)
                          BandRow(
                            child: Row(
                              children: [
                                SizedBox(width: 72, child: Text('${md(m.at)} ${hm(m.at)}', style: mono(11))),
                                Expanded(child: Text(m.text, style: body(14))),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
