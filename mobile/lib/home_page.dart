// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'bridge.dart';
import 'guide_page.dart';
import 'main.dart';
import 'settings_page.dart';
import 'tv_install_page.dart';
import 'ui.dart';

/// Ana ekran: altta yüzen cam sekme çubuğu ve üç sekme (Çeviri, Rehber, Ayarlar).
/// Çeviri sekmesi: başlat/durdur, PS5 · telefon · TV durumu, canlı önizleme ve son çeviri.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.setup, required this.onSetupChanged});

  final SetupInfo setup;
  final Future<void> Function() onSetupChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const tabs = [
    (CupertinoIcons.captions_bubble, CupertinoIcons.captions_bubble_fill, 'ترجمة'),
    (CupertinoIcons.book, CupertinoIcons.book_fill, 'Rehber'),
    (CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill, 'Ayarlar'),
  ];

  int tab = 0;
  EngineState state = const EngineState();
  AppSettings? settings;
  StreamSubscription<EngineState>? subscription;
  Timer? previewTimer;
  Uint8List? preview;
  late final AnimationController pulse;

  /// Görüntü akarken TV'nin bağlanmasının beklenmeye başladığı an; TV bağlıyken ya da çeviri kapalıyken null.
  DateTime? tvWaitingSince;

  /// TV uygulaması telefonu genelde birkaç saniyede bulur; bu kadar beklendiyse bir sorun vardır.
  static const tvWaitLimit = Duration(seconds: 25);

  bool get tvStuck => tvWaitingSince != null && DateTime.now().difference(tvWaitingSince!) > tvWaitLimit;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    subscription = Bridge.states.listen((next) {
      if (!mounted) return;
      setState(() {
        state = next;
        final waiting = next.phase == 'streaming' && next.tvClients == 0;
        tvWaitingSince = waiting ? (tvWaitingSince ?? DateTime.now()) : null;
      });
    });
    loadSettings();
    // Önizleme yalnız görüntü akarken yenilenir. Aynı sayaç, TV bekleme süresi dolunca uyarının değişmesini sağlar.
    previewTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshPreview();
      if (mounted && tvWaitingSince != null) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    previewTimer?.cancel();
    pulse.dispose();
    super.dispose();
  }

  bool get active => state.running || (state.phase != 'idle' && state.phase != 'failed');
  bool get streaming => state.phase == 'streaming';

  Future<void> loadSettings() async {
    final loaded = await Bridge.settings();
    if (mounted) setState(() => settings = loaded);
  }

  Future<void> refreshPreview() async {
    if (!streaming || tab != 0) return;
    final image = await Bridge.snapshot(width: 640);
    if (mounted && image != null) setState(() => preview = image);
  }

  /// Sekme değişir; Çeviri'ye dönülünce bölge çerçevesi güncel ayarlarla çizilsin diye ayarlar yeniden okunur.
  void selectTab(int index) {
    setState(() => tab = index);
    if (index == 0) loadSettings();
  }

  Future<void> toggle() async {
    if (active) {
      await Bridge.stop();
    } else {
      await Bridge.start();
    }
  }

  Future<void> sendTest() async {
    await Bridge.testSubtitle();
    if (!mounted) return;
    toast(context, state.tvClients > 0 ? 'تم إرسال الترجمة التجريبية إلى TV\'.' : 'التلفزيون غير متصل. أولاً، افتح GameTranslator\'على التلفاز\'.');
  }

  (String, String, Color) get headline => switch (state.phase) {
        'streaming' => ('الترجمة قيد التشغيل', 'يمكنك إيقاف تشغيل الشاشة. تستمر الترجمة في الخلفية.', Tokens.success),
        'starting' => ('جارٍ الإطلاق…', 'يستغرق بضع ثوان.', Tokens.warning),
        'connecting' => ('جارٍ الاتصال بجهاز PS5\'...', 'يجب أن يكون جهاز PS5 قيد التشغيل وعلى نفس شبكة Wi-Fi\'.', Tokens.warning),
        'waking' => ('PS5 يستيقظ…', 'قد يستغرق الأمر ما يصل إلى دقيقة للخروج من وضع السكون.', Tokens.warning),
        'reconnecting' => ('جارٍ إعادة الاتصال…', 'انقطع الاتصال، حاول مرة أخرى.', Tokens.warning),
        'stopping' => ('Durduruluyor…', '', Tokens.textSecondary),
        'failed' => ('فشل في التهيئة', 'انقر للمحاولة مرة أخرى.', Tokens.danger),
        _ => ('الترجمة معطلة', 'انقر للبدء.', Tokens.textSecondary),
      };

  List<FlowNode> get nodes {
    final connecting = const {'starting', 'connecting', 'waking', 'reconnecting'}.contains(state.phase);
    final address = state.localAddress;
    final tvOn = state.tvClients > 0;
    return [
      FlowNode(
        icon: CupertinoIcons.gamecontroller_fill,
        label: 'PS5',
        detail: streaming
            ? 'متصل'
            : switch (state.phase) {
                'waking' => 'الاستيقاظ',
                'starting' || 'connecting' || 'reconnecting' => 'ربط',
                _ => 'متطابق',
              },
        color: streaming ? Tokens.success : (connecting ? Tokens.warning : Tokens.textSecondary),
        busy: connecting,
      ),
      FlowNode(
        icon: CupertinoIcons.device_phone_portrait,
        label: 'Telefon',
        detail: address == null ? 'لا يوجد واي فاي' : (streaming ? 'ترجمة' : 'مستعد'),
        color: address == null ? Tokens.danger : (streaming ? Tokens.accent : Tokens.textSecondary),
      ),
      FlowNode(
        icon: CupertinoIcons.tv_fill,
        label: 'TV',
        detail: tvOn ? 'متصل' : (active ? 'Bekleniyor' : 'غير متصل'),
        color: tvOn ? Tokens.success : (active ? Tokens.warning : Tokens.textSecondary),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: tab,
                children: [
                  translateTab(),
                  const GuideTab(),
                  SettingsTab(setup: widget.setup, onSetupChanged: widget.onSetupChanged, active: tab == 2),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottom + 12,
                child: Center(child: GlassTabBar(items: tabs, index: tab, onTap: selectTab)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget translateTab() {
    final (title, hint, color) = headline;
    final failed = state.phase == 'failed';
    final tvOn = state.tvClients > 0;
    return LargeTitleList(
      title: 'GameTranslator',
      trailing: const GtLogo(size: 38, glow: false),
      children: [
        const SizedBox(height: 22),
        Center(
          child: _PowerButton(
            phase: state.phase,
            active: active,
            color: color,
            pulse: pulse,
            onTap: state.nativeAvailable && state.phase != 'stopping' ? toggle : null,
          ),
        ),
        const SizedBox(height: 22),
        Text(title, textAlign: TextAlign.center, style: Txt.title1),
        const SizedBox(height: 4),
        Text(
          failed && state.message.isNotEmpty ? state.message : hint,
          textAlign: TextAlign.center,
          style: Txt.subhead.copyWith(color: failed ? Tokens.danger : Tokens.textSecondary),
        ),
        const SizedBox(height: 26),
        FlowRow(nodes: nodes),
        if (!state.nativeAvailable) ...[
          const SizedBox(height: 12),
          const Notice(
            icon: CupertinoIcons.exclamationmark_circle_fill,
            color: Tokens.danger,
            title: 'هذا الهاتف غير مدعوم',
            text: 'تعذر تحميل مكتبة Remote Play على هذا الجهاز.',
          ),
        ],
        if (state.localAddress == null) ...[
          const SizedBox(height: 12),
          const Notice(
            icon: CupertinoIcons.wifi_slash,
            color: Tokens.danger,
            title: 'لا يوجد اتصال بالواي فاي',
            text: 'يجب أن يكون الهاتف متصلاً بنفس شبكة Wi-Fi مثل جهاز PS5 والتلفزيون.',
          ),
        ],
        if (streaming && !tvOn && !tvStuck) ...[
          const SizedBox(height: 12),
          const Notice(
            icon: CupertinoIcons.tv,
            color: Tokens.warning,
            title: 'افتح GameTranslator\'على التلفاز\'',
            text: 'يجد تطبيق التلفزيون الهاتف على الشبكة نفسها؛ يستغرق الأمر بضع ثوانٍ للاتصال بعد تشغيله.',
          ),
        ],
        if (streaming && !tvOn && tvStuck) ...[
          const SizedBox(height: 12),
          Notice(
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            color: Tokens.warning,
            title: 'التلفزيون لا يزال غير متصل',
            text: 'إذا كان تطبيق التلفزيون متصلاً بالكمبيوتر من قبل، فقد يكون عالقًا في العنوان القديم.'
                'يؤدي مسح بيانات التطبيق مرة واحدة على TV\' إلى إصلاح هذه المشكلة.',
            action: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => Navigator.of(context).push(appleRoute<void>((_) => const TvHelpPage())),
              child: const Text('تظهر خطوة بخطوة', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
        if (active) ...[
          const GroupHeader('CANLI'),
          _LiveCard(state: state, preview: streaming ? preview : null, settings: settings),
          const SizedBox(height: 12),
          Group(
            inset: 60,
            children: [
              Cell(icon: CupertinoIcons.captions_bubble_fill, iconColor: Tokens.indigo, title: 'إرسال ترجمات اختبارية إلى TV\'', onTap: sendTest),
              Cell(icon: CupertinoIcons.crop, iconColor: Tokens.teal, title: 'تعيين منطقة الترجمة', chevron: true, onTap: () => selectTab(2)),
            ],
          ),
        ] else ...[
          const GroupHeader('كيفية الاستخدام'),
          Group(
            inset: 60,
            children: [
              const _HowStep(number: 1, text: 'قم بتشغيل الترجمة في اللعبة.'),
              const _HowStep(number: 2, text: 'ابدأ الترجمة بالزر أعلاه.'),
              const _HowStep(number: 3, text: 'افتح GameTranslator\'on TV\'؛ تظهر الترجمة أعلى اللعبة.'),
              Cell(
                icon: CupertinoIcons.tv_fill,
                iconColor: Tokens.purple,
                title: 'تثبيت تطبيق التلفزيون',
                subtitle: 'إذا لم يكن هناك GameTranslator على جهاز التلفزيون الخاص بك\'',
                chevron: true,
                onTap: () => Navigator.of(context).push(appleRoute<void>((_) => const TvInstallPage())),
              ),
              Cell(icon: CupertinoIcons.book_fill, iconColor: Tokens.warning, title: 'دليل مفصل', chevron: true, onTap: () => selectTab(1)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ortadaki büyük başlat/durdur düğmesi: cam bir halkanın içinde, sol üstten ışık alan küre.
class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.phase, required this.active, required this.color, required this.pulse, required this.onTap});

  final String phase;
  final bool active;
  final Color color;
  final Animation<double> pulse;
  final VoidCallback? onTap;

  static const double outer = 172;
  static const double inner = 144;

  @override
  Widget build(BuildContext context) {
    final streaming = phase == 'streaming';
    final busy = active && !streaming;
    final idle = !active;
    final tone = idle ? (phase == 'failed' ? Tokens.danger : Tokens.accent) : color;
    return Semantics(
      button: true,
      label: active ? 'وقف الترجمة' : 'ابدأ الترجمة',
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          // Kapalıyken ve çeviri açıkken ışık yavaşça nefes alır; bağlanırken sabit kalır.
          final t = busy ? 0.3 : Curves.easeInOut.transform(pulse.value);
          return Container(
            width: outer,
            height: outer,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Tokens.glassFill,
              border: Border.all(color: Tokens.border, width: 0.8),
              boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.20 + 0.16 * t), blurRadius: 40 + 24 * t, spreadRadius: 2 + 4 * t)],
            ),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (busy) SizedBox(width: outer - 4, height: outer - 4, child: CircularProgressIndicator(strokeWidth: 2.5, color: color)),
            Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              child: Ink(
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: idle
                      ? const RadialGradient(
                          center: Alignment(-0.45, -0.55),
                          radius: 1.15,
                          colors: [Color(0xFF7CC0FF), Color(0xFF0A84FF), Color(0xFF0060DF)],
                          stops: [0, 0.48, 1],
                        )
                      : RadialGradient(
                          center: const Alignment(-0.45, -0.55),
                          radius: 1.15,
                          colors: [const Color(0x59FFFFFF), tone.withValues(alpha: streaming ? 0.30 : 0.12)],
                        ),
                  border: idle ? null : Border.all(color: tone.withValues(alpha: busy ? 0.3 : 0.9), width: 2),
                ),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    active ? CupertinoIcons.stop_fill : CupertinoIcons.play_fill,
                    size: active ? 46 : 54,
                    color: Colors.white.withValues(alpha: busy ? 0.6 : 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Nasıl kullanılır" listesindeki numaralı satır.
class _HowStep extends StatelessWidget {
  const _HowStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Tokens.surfaceHigh, borderRadius: BorderRadius.circular(7.2)),
            child: Text('$number', style: Txt.subhead.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: Txt.callout)),
        ],
      ),
    );
  }
}

/// Çeviri açıkken: oyun görüntüsü, altyazı bölgesi ve son çeviri.
class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.state, required this.preview, required this.settings});

  final EngineState state;
  final Uint8List? preview;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    final hasTranslation = state.lastTranslation.isNotEmpty;
    final streaming = state.phase == 'streaming';
    return Glass(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview != null)
            RegionPreview(image: preview!, settings: settings, subtitle: hasTranslation ? state.lastTranslation : null)
          else
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 12),
                    const SizedBox(height: 12),
                    Text(streaming ? 'جارٍ إعداد المعاينة…' : 'صورة PS5 متوقعة…', style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('أحدث الترجمة', style: Txt.headline)),
                    if (streaming) Pill(text: '${state.translated} الصف', color: Tokens.accent),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasTranslation) ...[
                  Text(state.lastTranslation, style: Txt.title3.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(state.lastSource.replaceAll('\n', ' '), style: Txt.subhead.copyWith(color: Tokens.textSecondary)),
                  if (state.packHits > 0 && state.packGame.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('تم استخدام حزمة ${state.packGame} · خط ${state.packHits} من الحزمة',
                        style: Txt.footnote.copyWith(color: Tokens.success)),
                  ],
                ] else
                  Text('عندما تظهر الترجمة في اللعبة، تظهر الترجمة هنا وعلى TV\'.', style: Txt.subhead.copyWith(color: Tokens.textSecondary)),
                if (streaming) ...[
                  const SizedBox(height: 14),
                  // Bölge doğru yerde mi ve yazı okunuyor mu, buradan anlaşılır.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Tokens.inset, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اقرأ في الإطار', style: Txt.caption.copyWith(color: Tokens.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                        const SizedBox(height: 3),
                        Text(
                          state.lastRead.isEmpty ? 'لا توجد مشاركات في الوقت الراهن.' : state.lastRead.replaceAll('\n', ' '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.footnote.copyWith(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Oyun görüntüsü, üstünde altyazının arandığı bölgenin çerçevesi ve (verildiyse) TV'deki gibi çeviri.
class RegionPreview extends StatelessWidget {
  const RegionPreview({super.key, required this.image, required this.settings, this.subtitle});

  final Uint8List image;
  final AppSettings? settings;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(image, fit: BoxFit.fill, gaplessPlayback: true),
            if (s != null)
              Positioned(
                left: s.regionValue('left') * constraints.maxWidth,
                top: s.regionValue('top') * constraints.maxHeight,
                width: (s.regionValue('right') - s.regionValue('left')) * constraints.maxWidth,
                height: (s.regionValue('bottom') - s.regionValue('top')) * constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Tokens.accent, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                    color: Tokens.accent.withValues(alpha: 0.10),
                  ),
                ),
              ),
            if (subtitle != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: Center(
                  child: Glass(
                    blur: true,
                    radius: 10,
                    tint: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
