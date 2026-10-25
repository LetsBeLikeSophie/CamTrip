import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../money.dart';
import '../store.dart';
import '../ui.dart';

/// Opens a voice memo to read, fix or delete.
Future<void> showMemoSheet(BuildContext context, AppStore store, Memo memo) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.ivory,
    barrierColor: C.navy.withValues(alpha: 0.35),
    shape: const RoundedRectangleBorder(),
    builder: (_) => _MemoSheet(store: store, memo: memo),
  );
}

class _MemoSheet extends StatefulWidget {
  final AppStore store;
  final Memo memo;
  const _MemoSheet({required this.store, required this.memo});

  @override
  State<_MemoSheet> createState() => _MemoSheetState();
}

class _MemoSheetState extends State<_MemoSheet> {
  late final _text = TextEditingController(text: widget.memo.text);
  late final _amount = TextEditingController(
    text: widget.memo.amount == null ? '' : formatMoney(widget.memo.amount!, null).replaceAll(',', ''),
  );
  late String _category = widget.memo.category;

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.updateMemo(
      widget.memo,
      text: _text.text,
      amount: double.tryParse(_amount.text),
      category: _category,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    await widget.store.deleteMemo(widget.memo);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.memo;
    final trip = widget.store.trips.where((t) => t.id == m.tripId).firstOrNull;
    final light1 = trip?.light1 ?? Color(TripPalette.fallback.light1);
    final dark1 = trip?.dark1 ?? Color(TripPalette.fallback.dark1);
    final currency = m.currency ?? currencyFor(trip?.lang ?? 'ja');
    const square = OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.navy));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextBand(label: '${md(m.at)} ${hm(m.at)} · 음성 메모', color: light1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
            child: TextField(
              controller: _text,
              maxLines: 4,
              minLines: 2,
              style: body(18),
              decoration: const InputDecoration(border: square, enabledBorder: square, focusedBorder: square),
            ),
          ),
          BandRow(
            child: Row(
              children: [
                SizedBox(width: 64, child: Text('경비', style: body(13, color: C.sub))),
                Text(currency, style: serif(18)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    style: serif(18),
                    decoration: InputDecoration(
                      hintText: '없으면 비워두세요',
                      hintStyle: body(13, color: C.sub),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BandRow(
            child: Wrap(
              spacing: 18,
              children: [
                for (final cat in expenseCategories)
                  InkWell(
                    onTap: () => setState(() => _category = cat),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        widthFactor: 1,
                        child: Text(
                          cat,
                          style: body(14,
                                  weight: _category == cat ? FontWeight.w600 : FontWeight.w400,
                                  color: _category == cat ? C.navy : C.sub)
                              .copyWith(decoration: _category == cat ? TextDecoration.underline : null),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
            child: Text('녹음은 남기지 않고 글자만 저장했어요.', style: body(12, color: C.sub)),
          ),
          Row(
            children: [
              Expanded(child: ActionBand(label: '지우기', color: light1, arrow: false, centered: true, onTap: _delete)),
              const SizedBox(width: 1),
              Expanded(child: ActionBand(label: '저장', color: dark1, centered: true, onTap: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
