import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../hold_photo.dart';
import '../models.dart';
import '../money.dart';
import '../store.dart';
import '../ui.dart';
import 'translate_screen.dart';

/// A receipt, read automatically. Shown to confirm; the user only fixes
/// what is wrong. Pops with 'retake' when the user wants another photo.
class ReceiptScreen extends StatelessWidget {
  final AppStore store;
  final Capture capture;
  const ReceiptScreen({super.key, required this.store, required this.capture});

  Future<void> _notReceipt(BuildContext context) async {
    await store.setKind(capture, CaptureKind.menu);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => TranslateScreen(store: store, capture: capture),
    ));
  }

  Future<void> _editAmount(BuildContext context) async {
    final controller = TextEditingController(
      text: capture.amount == null ? '' : formatMoney(capture.amount!, null).replaceAll(',', ''),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.ivory,
        surfaceTintColor: C.ivory,
        shape: const RoundedRectangleBorder(),
        title: Text('합계 고치기', style: serif(20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          style: serif(24),
          decoration: InputDecoration(
            prefixText: '${capture.currency ?? ''} ',
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: C.navy)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소', style: body(14, color: C.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('저장', style: body(14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (value == null) return;
    await store.setAmount(capture, double.tryParse(value));
  }

  Future<void> _retake(BuildContext context) async {
    await store.deleteCapture(capture);
    if (context.mounted) Navigator.of(context).pop('retake');
  }

  @override
  Widget build(BuildContext context) {
    final trip = store.trips.where((t) => t.id == capture.tripId).firstOrNull;
    final light1 = trip?.light1 ?? const Color(0xFFD6DDF0);
    final light2 = trip?.light2 ?? const Color(0xFFEBDCE8);
    final dark1 = trip?.dark1 ?? const Color(0xFF1E2547);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TopBar(
                leading: const BackArrow(),
                actions: [Text('경비', style: mono(12))],
              ),
              ContextBand(
                label: [if (trip != null) trip.place, '${md(capture.at)} ${hm(capture.at)}'].join(' · '),
                color: light1,
                trailing: TextButton(
                  onPressed: () => _notReceipt(context),
                  child: Text('영수증 아니에요',
                      style: body(12, color: textOn(light1)).copyWith(decoration: TextDecoration.underline)),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SerifTitle('이대로 저장할까요?', size: 28),
                    HoldPhoto(capture: capture),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _editAmount(context),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.navy))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('합계', style: body(12, color: C.sub)),
                                    Text(
                                      capture.amount == null
                                          ? '금액을 못 읽었어요'
                                          : formatMoney(capture.amount!, capture.currency),
                                      style: serif(capture.amount == null ? 20 : 32),
                                    ),
                                  ],
                                ),
                              ),
                              Text('눌러서 고치기',
                                  style: body(12, color: C.sub).copyWith(decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final item in capture.items)
                      BandRow(
                        minHeight: 48,
                        child: Row(
                          children: [
                            Expanded(child: Text(item.name, style: body(15))),
                            Text(formatMoney(item.amount, null), style: mono(13, color: C.navy)),
                          ],
                        ),
                      ),
                    BandRow(
                      minHeight: 60,
                      child: Wrap(
                        spacing: 18,
                        children: [
                          for (final cat in expenseCategories)
                            InkWell(
                              onTap: () => store.setCategory(capture, cat),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 44),
                                child: Align(
                                  widthFactor: 1,
                                  child: Text(
                                    cat,
                                    style: body(
                                      14,
                                      weight: capture.category == cat ? FontWeight.w600 : FontWeight.w400,
                                      color: capture.category == cat ? C.navy : C.sub,
                                    ).copyWith(
                                      decoration: capture.category == cat ? TextDecoration.underline : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    BandRow(
                      color: light2,
                      child: Text(
                        '사진 속 글자에서 읽은 금액이에요. 다르면 합계를 눌러 고칠 수 있어요.',
                        style: body(13, color: textOn(light2)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ActionBand(
                      label: '다시 찍기',
                      color: light1,
                      arrow: false,
                      centered: true,
                      onTap: () => _retake(context),
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: ActionBand(
                      label: '경비에 저장',
                      color: dark1,
                      centered: true,
                      onTap: () {
                        store.track('receipt_confirmed');
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
