import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../demo.dart';
import '../models.dart';
import '../money.dart';
import '../photo.dart';
import '../store.dart';
import '../translator_service.dart';
import '../ui.dart';
import '../voice.dart';
import 'receipt_screen.dart';
import 'translate_screen.dart';
import 'trips_screen.dart';

/// The current trip as a running journal: cover, numbers, then every record
/// by day. Two bands at the bottom: take a photo, or press and talk.
class HomeScreen extends StatefulWidget {
  final AppStore store;
  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Entry {
  final DateTime at;
  final String title;
  final String sub;
  final String tag;
  final VoidCallback onTap;
  const _Entry(this.at, this.title, this.sub, this.tag, this.onTap);
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _service = TranslatorService();
  String? _step;
  bool _talking = false;
  String _heard = '';
  int _demoIndex = 0;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    if (store.loadFailed) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => toast(context, '저장된 기록을 읽지 못했어요. 원래 파일은 따로 보관해 뒀어요.'));
    }
  }

  String get _userLang {
    final chosen = store.targetLang;
    if (chosen != null) return chosen;
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code.isEmpty ? 'ko' : code;
  }

  // ---- taking a photo -------------------------------------------------

  /// Web preview: no camera or ML Kit in the browser, so walk through the
  /// same flow with sample photos. The Chinese sample comes first to show
  /// the "new trip" question.
  Future<(String, TranslationOutput)> _demoRun() async {
    final order = [
      ...demoSamples.where((s) => s.lang != 'ja'),
      ...demoSamples.where((s) => s.lang == 'ja'),
    ];
    final s = order[_demoIndex++ % order.length];
    for (final step in ['글자 읽는 중', '번역 중']) {
      if (mounted) setState(() => _step = step);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    return (s.asset, TranslationOutput(s.lang, scriptFor(s.lang), s.blocks));
  }

  Future<void> _start(ImageSource source) async {
    store.track('capture_started', {'source': source.name});
    try {
      final String imagePath;
      final TranslationOutput out;
      if (kIsWeb) {
        (imagePath, out) = await _demoRun();
      } else {
        final file = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 2400);
        if (file == null || !mounted) return;
        imagePath = file.path;
        setState(() => _step = '글자 읽는 중');
        final tripLang = store.currentTrip?.lang;
        out = await _service.run(
          imagePath: file.path,
          scriptHint: tripLang != null ? scriptFor(tripLang) : store.scriptKey,
          targetLang: _userLang,
          tripLang: tripLang,
          onStep: (s) {
            if (mounted) setState(() => _step = s);
          },
        );
        await store.setScript(out.scriptKey);
      }
      if (!mounted) return;

      final now = DateTime.now();
      var trip = store.currentTrip;
      if (store.needsNewTrip(out.sourceLang, now)) {
        setState(() => _step = null);
        final answer = await _askNewTrip(out.sourceLang);
        if (!mounted) return;
        store.track('new_trip_answer', {'answer': answer == null ? 'continue' : 'new'});
        if (answer != null) {
          trip = await store.createTrip(country: answer.$1, city: answer.$2, lang: out.sourceLang, now: now);
        } else if (trip != null) {
          await store.addLang(trip, out.sourceLang);
        }
      }
      trip ??= await store.createTrip(country: guessCountry(out.sourceLang), city: '', lang: out.sourceLang, now: now);

      final capture = await store.addCapture(
        trip: trip,
        originalImagePath: imagePath,
        sourceLang: out.sourceLang,
        blocks: out.blocks,
        now: now,
      );
      if (!mounted) return;
      setState(() => _step = null);
      final result = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => capture.isReceipt
            ? ReceiptScreen(store: store, capture: capture)
            : TranslateScreen(store: store, capture: capture),
      ));
      if (result == 'retake' && mounted) _start(source);
    } on NoTextFound {
      store.track('translate_failed', {'reason': 'no_text'});
      if (mounted) toast(context, '글자를 찾지 못했어요. 글자가 크게 보이게 다시 찍어주세요.');
    } on ModelDownloadFailed {
      store.track('translate_failed', {'reason': 'model_download'});
      if (mounted) toast(context, '번역 언어팩을 내려받지 못했어요. 인터넷 연결을 확인해주세요.');
    } on UnsupportedLanguage catch (e) {
      store.track('translate_failed', {'reason': 'unsupported', 'lang': e.code});
      if (mounted) toast(context, '아직 번역할 수 없는 언어예요 (${e.code}).');
    } catch (e) {
      store.track('translate_failed', {'reason': 'other'});
      debugPrint('CamTrip error: $e');
      if (mounted) toast(context, '번역하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _step = null);
    }
  }

  /// Returns (country, city) for a new trip, or null to keep the current one.
  Future<(String, String)?> _askNewTrip(String lang) {
    final hasTrip = store.currentTrip != null;
    return showModalBottomSheet<(String, String)?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: C.ivory,
      barrierColor: C.navy.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => _NewTripSheet(lang: lang, canContinue: hasTrip),
    );
  }

  // ---- press and talk ------------------------------------------------

  String get _speechLocale {
    const locales = {'ko': 'ko_KR', 'en': 'en_US', 'ja': 'ja_JP', 'zh': 'zh_CN'};
    return locales[_userLang] ?? _userLang;
  }

  Future<void> _talkStart() async {
    if (store.currentTrip == null) {
      toast(context, '먼저 사진을 한 장 찍으면 여행이 시작돼요.');
      return;
    }
    setState(() {
      _talking = true;
      _heard = '';
    });
    final ok = await Mic.instance.start(
      localeId: _speechLocale,
      onText: (t) {
        if (mounted && _talking) setState(() => _heard = t);
      },
    );
    if (!ok && mounted) {
      if (kIsWeb) {
        setState(() => _heard = '시장에서 딸기 모찌 두 개 600엔');
      } else {
        setState(() => _talking = false);
        toast(context, '말로 메모하려면 마이크를 허용해주세요.');
      }
    }
  }

  Future<void> _talkEnd() async {
    if (!_talking) return;
    await Mic.instance.stop();
    // The last words arrive a moment after stopping.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final text = _heard.trim();
    setState(() => _talking = false);
    final trip = store.currentTrip;
    if (text.isEmpty || trip == null) return;
    final memo = await store.addMemo(trip, text, DateTime.now());
    if (mounted) {
      toast(context, memo.amount != null
          ? '메모를 남겼어요 · ${formatMoney(memo.amount!, memo.currency)} 경비로 셀게요'
          : '메모를 남겼어요');
    }
  }

  // ---- opening records ------------------------------------------------

  void _open(Capture c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => c.isReceipt ? ReceiptScreen(store: store, capture: c) : TranslateScreen(store: store, capture: c),
    ));
  }

  Future<void> _openMemo(Memo m) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.ivory,
        surfaceTintColor: C.ivory,
        shape: const RoundedRectangleBorder(),
        title: Text('${md(m.at)} ${hm(m.at)} 메모', style: serif(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text, style: body(16)),
            if (m.amount != null) ...[
              const SizedBox(height: 10),
              Text('경비로 셈: ${formatMoney(m.amount!, m.currency)}', style: body(13, color: C.sub)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('지우기', style: body(14, color: C.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('닫기', style: body(14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (delete == true) await store.deleteMemo(m);
  }

  Future<void> _pickCover(Trip trip) async {
    final photos = store.capturesOf(trip);
    if (photos.isEmpty) return;
    final path = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.ivory,
      barrierColor: C.navy.withValues(alpha: 0.35),
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => _CoverSheet(trip: trip, photos: photos),
    );
    if (path != null) await store.setCover(trip, path);
  }

  List<_Entry> _entries(Trip trip) {
    final list = <_Entry>[
      for (final c in store.capturesOf(trip))
        c.isReceipt
            ? _Entry(
                c.at,
                '영수증 ${c.amount == null ? '' : formatMoney(c.amount!, c.currency)}'.trim(),
                c.items.map((i) => i.name).take(3).join(' · '),
                '경비',
                () => _open(c),
              )
            : _Entry(
                c.at,
                c.summary,
                c.blocks.isEmpty ? '' : c.blocks.first.source.replaceAll('\n', ' '),
                '번역',
                () => _open(c),
              ),
      for (final m in store.memosOf(trip))
        _Entry(m.at, m.text, m.amount != null ? '음성 메모 · 경비' : '음성 메모', '메모', () => _openMemo(m)),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.currentTrip;
        final light1 = trip?.light1 ?? Color(TripPalette.fallback.light1);
        final dark1 = trip?.dark1 ?? Color(TripPalette.fallback.dark1);
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    TopBar(
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text('CamTrip', style: serif(20, weight: FontWeight.w600)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: _step == null ? () => _start(ImageSource.gallery) : null,
                          child: Text('앨범에서', style: body(13)),
                        ),
                        IconButton(
                          tooltip: '여행 목록',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => TripsScreen(store: store)),
                          ),
                          icon: const Icon(Icons.view_agenda_outlined, color: C.navy),
                        ),
                      ],
                    ),
                    Expanded(child: trip == null ? _empty(light1) : _journal(trip)),
                    Row(
                      children: [
                        Expanded(
                          child: ActionBand(
                            label: '찍기',
                            icon: Icons.photo_camera_outlined,
                            color: dark1,
                            centered: true,
                            onTap: _step == null ? () => _start(ImageSource.camera) : null,
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: '누르고 있는 동안 말하기',
                            child: Listener(
                              onPointerDown: (_) => _talkStart(),
                              onPointerUp: (_) => _talkEnd(),
                              onPointerCancel: (_) => _talkEnd(),
                              child: Container(
                                height: 72 + MediaQuery.paddingOf(context).bottom,
                                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                                color: _talking ? C.navy : light1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.mic_none, size: 22, color: textOn(_talking ? C.navy : light1)),
                                    const SizedBox(width: 10),
                                    Text(
                                      _talking ? '듣고 있어요' : '누르고 말하기',
                                      style: body(15,
                                          weight: FontWeight.w500, color: textOn(_talking ? C.navy : light1)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_talking)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 72 + MediaQuery.paddingOf(context).bottom,
                  child: Container(
                    color: C.navy,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('듣고 있어요 · 놓으면 메모로 남겨요', style: body(13, color: C.ivory.withValues(alpha: 0.8))),
                        const SizedBox(height: 8),
                        Text(_heard.isEmpty ? '…' : _heard, style: body(17, color: C.ivory)),
                      ],
                    ),
                  ),
                ),
              if (_step != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: C.ivory.withValues(alpha: 0.94),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2, color: C.navy),
                          ),
                          const SizedBox(height: 16),
                          Text(_step!, style: body(15)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(Color light1) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ContextBand(label: '아직 여행이 없어요', color: light1),
        const SerifTitle('읽지 못한 글자를\n찍어보세요.', size: 34),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '메뉴나 간판을 찍으면 바로 한국어로 보여줘요. 처음 찍은 날부터 여행이 시작되고, '
            '영수증과 말로 남긴 메모가 날마다 쌓여요.',
            style: body(14, color: C.sub, height: 1.6),
          ),
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text('웹 미리보기: 샘플 사진으로 흐름만 보여줘요', style: body(12, color: C.sub)),
          ),
      ],
    );
  }

  Widget _journal(Trip trip) {
    final now = DateTime.now();
    final day = trip.dayOf(now);
    final currency = currencyFor(trip.lang);
    final entries = _entries(trip);
    final days = <DateTime, List<_Entry>>{};
    for (final e in entries) {
      days.putIfAbsent(DateTime(e.at.year, e.at.month, e.at.day), () => []).add(e);
    }
    final translated = store.capturesOf(trip).where((c) => !c.isReceipt).length;
    final cover = trip.coverPath;

    Widget stat(String value, String label, {bool first = false}) => Padding(
          padding: EdgeInsets.fromLTRB(first ? 24 : 0, 14, 0, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: serif(22))),
              Text(label, style: body(12, color: C.sub)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        ContextBand(
          label: '${trip.place.isEmpty ? '여행' : trip.place} · DAY ${day.toString().padLeft(2, '0')}',
          color: trip.light1,
          trailing: Text(md(now), style: mono(12, color: textOn(trip.light1))),
          onTap: () => _pickCover(trip),
        ),
        SerifTitle('${trip.place.isEmpty ? '여행' : trip.place},\n$day일째 기록 중.', size: 34),
        Semantics(
          label: '대표 사진. 눌러서 바꾸기',
          button: true,
          child: GestureDetector(
            onTap: () => _pickCover(trip),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: cover == null
                  ? ColoredBox(color: trip.dark2)
                  : capturePhoto(cover, fit: BoxFit.cover, cacheWidth: 900),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.navy))),
          child: Row(
            children: [
              Expanded(child: stat('$translated', '번역', first: true)),
              Expanded(child: stat('${store.dishesOf(trip)}', '먹은 메뉴')),
              Expanded(child: stat(formatMoney(store.spentOf(trip), currency), '지출')),
            ],
          ),
        ),
        for (final d in days.keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    d.year == now.year && d.month == now.month && d.day == now.day
                        ? '오늘'
                        : 'DAY ${trip.dayOf(d).toString().padLeft(2, '0')} · ${md(d)}',
                    style: serif(20),
                  ),
                ),
                Text('${formatMoney(store.spentOf(trip, day: d), currency)} 씀', style: body(12, color: C.sub)),
              ],
            ),
          ),
          for (final e in days[d]!)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: e.onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
                  child: Row(
                    children: [
                      SizedBox(width: 44, child: Text(hm(e.at), style: mono(11))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(15)),
                            if (e.sub.isNotEmpty)
                              Text(e.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.sub)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(e.tag, style: body(12, color: C.sub)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _NewTripSheet extends StatefulWidget {
  final String lang;
  final bool canContinue;
  const _NewTripSheet({required this.lang, required this.canContinue});

  @override
  State<_NewTripSheet> createState() => _NewTripSheetState();
}

class _NewTripSheetState extends State<_NewTripSheet> {
  late final _country = TextEditingController(text: guessCountry(widget.lang));
  final _city = TextEditingController();

  @override
  void dispose() {
    _country.dispose();
    _city.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController c, String hint) {
    return BandRow(
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(label, style: body(13, color: C.sub))),
          Expanded(
            child: TextField(
              controller: c,
              style: serif(17),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: body(14, color: C.sub),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final light1 = Color(TripPalette.fallback.light1);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextBand(label: '${langNames[widget.lang] ?? '새 언어'} 글자를 처음 찍었어요', color: light1),
          const SerifTitle('새 여행을 시작할게요', size: 28),
          Container(height: 1, color: C.navy),
          _field('나라', _country, '나라'),
          _field('도시', _city, '안 적어도 돼요'),
          BandRow(
            child: Row(
              children: [
                SizedBox(width: 56, child: Text('시작', style: body(13, color: C.sub))),
                Text('${md(DateTime.now())} 오늘', style: body(15)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Text('여행기 제목은 다녀온 뒤에 알아서 지어드려요.', style: body(12, color: C.sub)),
          ),
          if (widget.canContinue)
            LinkBand(label: '지난 여행에 이어서 기록하기', color: light1, onTap: () => Navigator.pop(context, null)),
          ActionBand(
            label: '좋아요',
            color: C.navy,
            onTap: () => Navigator.pop(context, (_country.text.trim(), _city.text.trim())),
          ),
        ],
      ),
    );
  }
}

class _CoverSheet extends StatelessWidget {
  final Trip trip;
  final List<Capture> photos;
  const _CoverSheet({required this.trip, required this.photos});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Text('${trip.place} 대표 사진', style: serif(22)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Text('사진 하나를 고르면 그 사진에서 이 여행의 색을 뽑아요.', style: body(12, color: C.sub)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in photos)
                  Semantics(
                    button: true,
                    selected: c.imagePath == trip.coverPath,
                    label: '${hm(c.at)} 사진으로 정하기',
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, c.imagePath),
                      child: Container(
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 2),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            capturePhoto(c.imagePath, fit: BoxFit.cover, cacheWidth: 600),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                color: C.ivory,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                child: Text(
                                  c.imagePath == trip.coverPath ? '✓ ${hm(c.at)}' : hm(c.at),
                                  style: mono(12, color: C.navy),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ActionBand(label: '닫기', color: C.navy, arrow: false, centered: true, onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
