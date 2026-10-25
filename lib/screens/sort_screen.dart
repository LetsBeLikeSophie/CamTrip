import 'package:flutter/material.dart';

import '../models.dart';
import '../money.dart';
import '../store.dart';
import '../ui.dart';
import 'memo_sheet.dart';

/// Evening wrap-up: voice memos sorted into expenses or diary lines by
/// simple rules on the phone. The user only confirms ("맞아요") or fixes.
class SortScreen extends StatelessWidget {
  final AppStore store;
  const SortScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.currentTrip;
        final light1 = trip?.light1 ?? Color(TripPalette.fallback.light1);
        final light2 = trip?.light2 ?? Color(TripPalette.fallback.light2);
        final dark1 = trip?.dark1 ?? Color(TripPalette.fallback.dark1);
        final waiting = trip == null ? <Memo>[] : store.unsortedMemosOf(trip);
        final now = DateTime.now();
        final receiptsToday = trip == null
            ? <Capture>[]
            : store
                .capturesOf(trip)
                .where((c) => c.isReceipt && c.at.year == now.year && c.at.month == now.month && c.at.day == now.day)
                .toList();
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(
                  leading: const BackArrow(),
                  actions: [Text(waiting.isEmpty ? '다 정리됨' : '남은 메모 ${waiting.length}개', style: body(12, color: C.sub))],
                ),
                ContextBand(
                  label: trip == null ? '저녁 정리' : '${trip.place} · DAY ${trip.dayOf(now).toString().padLeft(2, '0')}',
                  color: light1,
                  trailing: Text(md(now), style: mono(12, color: textOn(light1))),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SerifTitle('오늘 정리', size: 32),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Text(
                          waiting.isEmpty ? '정리할 메모가 없어요. 오늘도 잘 다녔어요.' : '말로 남긴 메모를 이렇게 나눠봤어요. 맞으면 눌러주세요.',
                          style: body(13, color: C.sub),
                        ),
                      ),
                      Container(height: 1, color: C.navy),
                      for (final m in waiting) _MemoRow(store: store, memo: m, dark1: dark1),
                      for (final c in receiptsToday)
                        BandRow(
                          child: Row(
                            children: [
                              SizedBox(width: 46, child: Text(hm(c.at), style: mono(11))),
                              Expanded(
                                child: Text(
                                  '영수증 ${c.amount == null ? '' : formatMoney(c.amount!, c.currency)} · 이미 경비로 들어갔어요',
                                  style: body(13, color: C.sub),
                                ),
                              ),
                            ],
                          ),
                        ),
                      BandRow(
                        color: light2,
                        minHeight: 64,
                        child: Text(
                          '하루 페이지(AI가 쓰는 일기)는 서버를 붙이면 여기서 이어서 만들어요.',
                          style: body(13, color: textOn(light2)),
                        ),
                      ),
                    ],
                  ),
                ),
                ActionBand(
                  label: waiting.isEmpty ? '홈으로' : '나머지는 이대로 두기',
                  color: dark1,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemoRow extends StatelessWidget {
  final AppStore store;
  final Memo memo;
  final Color dark1;
  const _MemoRow({required this.store, required this.memo, required this.dark1});

  @override
  Widget build(BuildContext context) {
    final m = memo;
    final expense = m.amount != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 0, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 46, child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(hm(m.at), style: mono(11)))),
                Expanded(child: Text('“${m.text}”', style: body(14, color: C.sub, height: 1.5))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense ? '경비 · ${m.category}' : '하루 기록에 넣을 문장', style: body(12, color: C.sub)),
                      Text(
                        expense ? formatMoney(m.amount!, m.currency) : m.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: serif(16),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showMemoSheet(context, store, m),
                  child: Text('고치기', style: body(13, color: C.sub).copyWith(decoration: TextDecoration.underline)),
                ),
                Material(
                  color: dark1,
                  child: InkWell(
                    onTap: () => store.confirmMemo(m),
                    child: SizedBox(
                      width: 72,
                      height: 44,
                      child: Center(child: Text('맞아요', style: body(13, weight: FontWeight.w500, color: textOn(dark1)))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
