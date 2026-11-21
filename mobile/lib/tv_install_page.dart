// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'guide_page.dart';
import 'main.dart';
import 'tv_install.dart';
import 'ui.dart';

/// TV app installer wizard from phone: brand -> find TV -> developer steps -> install -> launch.
class TvInstallPage extends StatefulWidget {
  const TvInstallPage({super.key});

  @override
  State<TvInstallPage> createState() => _TvInstallPageState();
}

enum _Step { brand, samsung, find, guide, install, done }

/// Single developer-mode step with optional live port check.
class _GuideStep {
  const _GuideStep(this.title, this.body, {this.different, this.check = _Check.none, this.copy});

  final String title;
  final String body;

  /// Alternative menu path if the TV UI differs.
  final String? different;
  final _Check check;

  /// Copyable string such as a URL.
  final String? copy;
}

enum _Check { none, ready, keyServer }

const _androidSteps = [
  _GuideStep(
    'افتح الإعدادات في التلفاز',
    'اضغط زر الإعدادات (الترس) في ريموت التلفاز. إذا لم يكن موجوداً، اختر أيقونة الترس أعلى يمين الشاشة الرئيسية.',
    different: 'في Google TV (موديلات Sony و TCL و Philips و Xiaomi الحديثة) اختر صورة الملف الشخصي أو الترس أعلى اليمين ثم ادخل "الإعدادات".',
  ),
  _GuideStep(
    'ادخل إلى شاشة "حول"',
    'في Android TV: الإعدادات › تفضيلات الجهاز › حول.\nفي Google TV: الإعدادات › النظام › حول.',
    different: 'في Philips: الإعدادات › إعدادات Android › تفضيلات الجهاز › حول.\n'
        'في Sony: الإعدادات › النظام › حول (في الموديلات القديمة: تفضيلات الجهاز › حول).\n'
        'في TCL و Xiaomi: الإعدادات › النظام › حول أو تفضيلات الجهاز › حول.\n'
        'إذا كان هناك بحث في الإعدادات فاكتب "حول".',
  ),
  _GuideStep(
    'اضغط على رقم الإصدار 7 مرات',
    'اختر سطر "إصدار نظام Android TV" أسفل القائمة واضغط زر الموافق في الريموت 7 مرات متتالية حتى تظهر رسالة "أنت الآن مطوّر".',
    different: 'قد يظهر السطر باسم "رقم الإصدار" أو "Build number" حسب الطراز. إذا طلب التلفاز رمز PIN أدخل رمز القفل. إذا ظهر "أنت مطوّر بالفعل" فهذه الخطوة مكتملة.',
  ),
  _GuideStep(
    'افتح "خيارات المطوّر"',
    'ارجع خطوة واحدة للخلف؛ سيظهر خيار "خيارات المطوّر" ضمن تفضيلات الجهاز أو النظام، ادخل إليه.',
    different: 'إذا لم يظهر، اخرج من الإعدادات بالكامل ثم عد إليها، أو كرر الضغط 7 مرات في الخطوة السابقة.',
  ),
  _GuideStep(
    'فعّل "تصحيح أخطاء USB"',
    'ابحث عن "تصحيح أخطاء USB" داخل خيارات المطوّر وفعّله، ثم اضغط "موافق" في رسالة التنبيه. إذا وجدت "تصحيح الأخطاء عبر الشبكة" أو "ADB debugging" ففعّله أيضاً.\n\nعند تفعيله سيتحول المؤشر هنا إلى الأخضر تلقائياً.',
    different: 'قد يظهر الخيار باسم "تصحيح أخطاء ADB" أو "USB debugging". الأجهزة التي توفر "Wireless debugging" برمز إقران فقط لا تدعم التثبيت المباشر من الهاتف حالياً؛ استخدم طريقة USB من الدليل.',
    check: _Check.ready,
  ),
];

const _lgSteps = [
  _GuideStep(
    'أنشئ حساب مطوّر LG مجاني',
    'افتح الرابط أدناه في متصفح الهاتف، واضغط "SIGN IN" ثم "Create Account" لإنشاء حساب مجاني واستخدام بريده وكلمة مروره في الخطوة التالية.',
    different: 'إذا كان لديك حساب LG مسبقاً (مثل LG ThinQ) يمكنك تسجيل الدخول بنفس البريد وكلمة المرور وتجاوز هذه الخطوة.',
    copy: 'https://webostv.developer.lge.com',
  ),
  _GuideStep(
    'ثبّت تطبيق "Developer Mode" على التلفاز',
    'افتح متجر LG Content Store في التلفاز، وابحث عن "Developer Mode" ثم ثبّته.',
    different: 'إذا لم يفتح المتجر تأكد من اتصال التلفاز بالإنترنت. قد يظهر المتجر باسم "LG Store" أو "التطبيقات"، وتظهر واجهة التطبيق بالإنجليزية.',
  ),
  _GuideStep(
    'سجّل الدخول وفعّل "Dev Mode Status"',
    'افتح تطبيق Developer Mode وسجّل الدخول بحساب LG، ثم فعّل مفتاح "Dev Mode Status". سيعيد التلفاز التشغيل تلقائياً، انتظر حتى يكتمل الإقلاع.\n\nسيتحول المؤشر هنا إلى الأخضر تلقائياً عند تفعيل وضع المطوّر.',
    different: 'إذا كان المفتاح غير نشط فتأكد من تسجيل الدخول أولاً. إذا ظهرت رسالة "Login failed" فتأكد من تأكيد البريد الإلكتروني للحساب.',
    check: _Check.ready,
  ),
  _GuideStep(
    'فعّل "Key Server"',
    'بعد إعادة تشغيل التلفاز افتح Developer Mode مرة أخرى وفعّل "Key Server". اترك التطبيق مفتوحاً على الشاشة؛ إغلاقه يوقف Key Server.\n\nسيتحول المؤشر هنا إلى الأخضر تلقائياً عند تشغيله.',
    different: 'سيظهر رمز "Passphrase" المكوّن من 6 أحرف أسفل يسار الشاشة؛ ستحتاجه في الخطوة التالية.',
    check: _Check.keyServer,
  ),
];

class _TvInstallPageState extends State<TvInstallPage> {
  _Step step = _Step.brand;
  TvKind? kind;
  String? host;
  String tvName = '';
  bool force = false;

  SavedTv? saved;
  Map<TvKind, String> bundled = {};
  String? phone;

  List<FoundTv> found = [];
  bool searching = false;
  bool searched = false;
  final manualController = TextEditingController();
  String? manualError;

  int guideIndex = 0;
  TvCheck? check;
  Timer? poll;
  bool polling = false;

  final passController = TextEditingController();
  bool installing = false;
  String stage = '';
  TvInstallResult? result;
  StreamSubscription<String>? stages;

  @override
  void initState() {
    super.initState();
    stages = TvBridge.stages.listen((value) {
      if (mounted) setState(() => stage = value);
    });
    () async {
      final values = await Future.wait([TvBridge.saved(), TvBridge.bundled(), TvBridge.phoneAddress()]);
      if (!mounted) return;
      setState(() {
        saved = values[0] as SavedTv?;
        bundled = values[1] as Map<TvKind, String>;
        phone = values[2] as String?;
      });
    }();
  }

  @override
  void dispose() {
    poll?.cancel();
    stages?.cancel();
    if (installing || searching) TvBridge.cancel();
    manualController.dispose();
    passController.dispose();
    super.dispose();
  }

  List<_GuideStep> get guideSteps => switch (kind) {
        TvKind.android => _androidSteps,
        // Key Server step is skipped when the LG key is already saved.
        TvKind.lg => check?.hasKey == true ? _lgSteps.sublist(0, 3) : _lgSteps,
        _ => const [],
      };

  // ------------------------------------------------------------------------------------------- Navigation
  void go(_Step next) {
    poll?.cancel();
    setState(() {
      step = next;
      if (next != _Step.install) result = null;
    });
    if (next == _Step.find) search();
    if (next == _Step.guide) startPolling();
  }

  void chooseBrand(TvKind value) {
    setState(() {
      kind = value;
      host = null;
      found = [];
      searched = false;
      check = null;
      guideIndex = 0;
      force = false;
    });
    go(value == TvKind.samsung ? _Step.samsung : _Step.find);
  }

  /// Installs or updates directly on a previously saved TV.
  Future<void> reinstallSaved(SavedTv tv) async {
    setState(() {
      kind = tv.kind;
      host = tv.host;
      tvName = tv.name;
      force = true;
      guideIndex = 0;
    });
    final status = await TvBridge.check(tv.kind, tv.host);
    if (!mounted) return;
    setState(() => check = status);
    if (status.ready && (tv.kind != TvKind.lg || status.hasKey)) {
      go(_Step.install);
      install();
    } else {
      go(_Step.guide);
    }
  }

  void back() {
    switch (step) {
      case _Step.brand:
        Navigator.of(context).pop();
      case _Step.samsung || _Step.find:
        go(_Step.brand);
      case _Step.guide:
        if (guideIndex > 0) {
          setState(() => guideIndex--);
          startPolling();
        } else {
          go(_Step.find);
        }
      case _Step.install:
        if (installing) {
          TvBridge.cancel();
          return;
        }
        setState(() => guideIndex = guideSteps.length - 1);
        go(_Step.guide);
      case _Step.done:
        Navigator.of(context).pop();
    }
  }

  // ------------------------------------------------------------------------------------------- Discovery
  Future<void> search() async {
    final current = kind;
    if (current == null || searching) return;
    setState(() {
      searching = true;
      manualError = null;
    });
    final list = await TvBridge.find(current);
    if (!mounted || kind != current) return;
    setState(() {
      searching = false;
      searched = true;
      found = list;
    });
  }

  Future<void> useManual() async {
    final address = await TvBridge.normalize(manualController.text);
    if (!mounted) return;
    if (address == null) {
      setState(() => manualError = 'عنوان IP غير صالح. مثال: 192.168.1.40');
      return;
    }
    FocusScope.of(context).unfocus();
    selectTv(address, kind?.title ?? 'TV');
  }

  Future<void> selectTv(String address, String name) async {
    setState(() {
      host = address;
      tvName = name;
      guideIndex = 0;
      manualError = null;
    });
    final status = await TvBridge.check(kind!, address);
    if (!mounted) return;
    setState(() => check = status);
    // Skip guide steps if developer mode is already enabled.
    if (status.ready && (kind == TvKind.android || status.hasKey)) {
      go(_Step.install);
    } else {
      if (status.ready && kind == TvKind.lg) guideIndex = 3; // Only Key Server remains.
      go(_Step.guide);
    }
  }

  // ------------------------------------------------------------------------------------------- Live check
  void startPolling() {
    poll?.cancel();
    final current = guideSteps.elementAtOrNull(guideIndex);
    if (current == null || current.check == _Check.none) return;
    poll = Timer.periodic(const Duration(seconds: 3), (_) => probe());
    probe();
  }

  Future<void> probe() async {
    final current = kind;
    if (polling || current == null) return;
    polling = true;
    try {
      var address = host;
      if (address == null && current == TvKind.android) {
        // Android TV becomes discoverable once debugging is enabled.
        final list = await TvBridge.find(current);
        if (list.isNotEmpty) {
          address = list.first.host;
          if (mounted) setState(() => host = address);
        }
      }
      if (address == null) return;
      final status = await TvBridge.check(current, address);
      if (mounted) setState(() => check = status);
    } finally {
      polling = false;
    }
  }

  bool stepDone(_GuideStep s) => switch (s.check) {
        _Check.none => false,
        _Check.ready => check?.ready == true,
        _Check.keyServer => check?.keyServer == true,
      };

  void nextGuide() {
    if (guideIndex + 1 < guideSteps.length) {
      setState(() => guideIndex++);
      startPolling();
    } else {
      go(_Step.install);
    }
  }

  // ------------------------------------------------------------------------------------------- Install
  bool get needsPassphrase => kind == TvKind.lg && check?.hasKey != true;

  Future<void> install() async {
    final current = kind;
    final address = host;
    if (current == null || address == null || installing) return;
    final pass = passController.text.trim();
    if (current == TvKind.lg && needsPassphrase && pass.isEmpty) {
      setState(() => result = const TvInstallResult(ok: false, error: 'WRONG_PASSPHRASE', detail: 'الرمز فارغ'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      installing = true;
      result = null;
      stage = 'connecting';
    });
    final outcome = await TvBridge.install(current, address, name: tvName, passphrase: needsPassphrase ? pass : null, force: force);
    if (!mounted) return;
    setState(() {
      installing = false;
      result = outcome;
      if (outcome.ok) step = _Step.done;
      // Prompt for passphrase again if saved key was rejected.
      if (outcome.error == 'KEY_REFUSED' || outcome.error == 'WRONG_PASSPHRASE') check = TvCheck(check?.ready ?? false, check?.keyServer ?? false, false);
    });
    if (outcome.ok) TvBridge.saved().then((value) => mounted ? setState(() => saved = value) : null);
  }

  // ------------------------------------------------------------------------------------------- View
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: step == _Step.brand || step == _Step.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: GlassScaffold(
        title: 'تثبيت تطبيق التلفاز',
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey('$step-$guideIndex'),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: switch (step) {
                _Step.brand => brandView(),
                _Step.samsung => samsungView(),
                _Step.find => findView(),
                _Step.guide => guideView(),
                _Step.install => installView(),
                _Step.done => doneView(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget progress(int index, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i <= index ? Tokens.accent : Tokens.surfaceHigh,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('الخطوة ${index + 1} من 4', style: Txt.footnote.copyWith(color: Tokens.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(title, style: Txt.title2),
          ],
        ),
      );

  // ----- 1. Brand
  List<Widget> brandView() {
    final tv = saved;
    return [
      progress(0, 'ما نوع التلفاز؟'),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Text(
          'سنثبّت تطبيق GameTranslator الخاص بالتلفاز من الهاتف لعرض الترجمة. تأكد أن الهاتف والتلفاز على نفس شبكة Wi-Fi.',
          style: Txt.subhead.copyWith(color: Tokens.textSecondary),
        ),
      ),
      if (tv != null) ...[
        const GroupHeader('تلفاز محفوظ'),
        Group(
          inset: 60,
          children: [
            Cell(
              icon: CupertinoIcons.tv_fill,
              iconColor: Tokens.success,
              title: tv.name.isEmpty ? tv.kind.title : tv.name,
              subtitle: '${tv.host} · على التلفاز ${tv.version ?? '?'} · في الهاتف ${bundled[tv.kind] ?? '?'}',
              trailing: tv.version != null && bundled[tv.kind] != null && _newer(bundled[tv.kind]!, tv.version!)
                  ? const Pill(text: 'يتوفر تحديث', color: Tokens.warning)
                  : null,
            ),
            Cell(
              title: tv.version != null && bundled[tv.kind] != null && _newer(bundled[tv.kind]!, tv.version!) ? 'تحديث' : 'إعادة التثبيت',
              titleColor: Tokens.accent,
              onTap: () => reinstallSaved(tv),
            ),
          ],
        ),
      ],
      const GroupHeader('النظام / الماركة'),
      Group(
        inset: 60,
        children: [
          Cell(
            icon: CupertinoIcons.tv,
            iconColor: Tokens.success,
            title: 'Android TV / Google TV',
            subtitle: 'TCL و Sony و Philips و Xiaomi وغيرها من شاشات Android TV / Google TV.',
            chevron: true,
            onTap: () => chooseBrand(TvKind.android),
          ),
          Cell(
            icon: CupertinoIcons.tv,
            iconColor: Tokens.danger,
            title: 'LG',
            subtitle: 'نظام webOS. يحتوي على LG Content Store وشريط التطبيقات في الأسفل.',
            chevron: true,
            onTap: () => chooseBrand(TvKind.lg),
          ),
          Cell(
            icon: CupertinoIcons.tv,
            iconColor: Tokens.accent,
            title: 'Samsung',
            subtitle: 'نظام Tizen (2019 فأحدث). يحتوي على Samsung TV Plus و Smart Hub.',
            chevron: true,
            onTap: () => chooseBrand(TvKind.samsung),
          ),
        ],
      ),
      const GroupFooter(
        'إذا لم تكن متأكداً، راجع الطراز ونظام التشغيل من إعدادات التلفاز › حول. '
        'بعض الأنظمة المحدودة مثل Philips Saphi و Titan OS غير مدعومة.',
      ),
    ];
  }

  // ----- Samsung: currently via desktop
  List<Widget> samsungView() => [
        progress(0, 'Samsung: التثبيت من الحاسوب حالياً'),
        const Notice(
          icon: CupertinoIcons.desktopcomputer,
          color: Tokens.warning,
          title: 'التثبيت من الهاتف غير متاح لـ Samsung حالياً',
          text: 'يتطلب نظام Tizen توقيع الحزمة بحساب Samsung لكل شاشة، ويتولى تطبيق الحاسوب ذلك حالياً. بعد إتمام التثبيت مرة واحدة لن تحتاج الحاسوب لاحقاً.',
        ),
        const SizedBox(height: 14),
        SectionCard(
          icon: CupertinoIcons.list_number,
          title: 'ملخص الخطوات',
          children: const [
            _Numbered(1, 'افتح شاشة التطبيقات في التلفاز واضغط الأزرار 1 2 3 4 5 من الريموت.'),
            _Numbered(2, 'فعّل "Developer mode" وأدخل عنوان IP الخاص بالحاسوب في "Host PC IP" ثم اضغط OK.'),
            _Numbered(3, 'أعد تشغيل التلفاز بالضغط المطوّل على زر التشغيل.'),
            _Numbered(4, 'من تطبيق GameTranslator على الحاسوب اختر شاشة Samsung وسجّل الدخول بحساب Samsung.'),
          ],
        ),
        const SizedBox(height: 16),
        GlowButton(
          icon: CupertinoIcons.book_fill,
          label: 'عرض التفاصيل في الدليل',
          onPressed: () => Navigator.of(context).push(appleRoute<void>((_) => const GuideChapterPage(index: 3))),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => go(_Step.brand), child: const Text('اختيار نظام آخر')),
      ];

  // ----- 2. Find TV
  List<Widget> findView() {
    final current = kind!;
    final android = current == TvKind.android;
    return [
      progress(1, 'ابحث عن التلفاز'),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Text(
          android
              ? 'يتم البحث عن أجهزة Android TV المفعّل بها تصحيح الأخطاء على الشبكة. إذا لم يكن مفعّلاً بعد فاختر "عرض الخطوات" للمتابعة.'
              : 'يتم البحث عن أجهزة LG TV المتصلة بنفس شبكة Wi-Fi. تأكد أن التلفاز يعمل.',
          style: Txt.subhead.copyWith(color: Tokens.textSecondary),
        ),
      ),
      GroupHeader(searching ? 'جارٍ البحث…' : 'الأجهزة المكتشفة'),
      Group(
        inset: 60,
        children: [
          if (searching)
            const Cell(title: 'جارٍ فحص الشبكة…', trailing: CupertinoActivityIndicator())
          else if (found.isEmpty)
            Cell(title: searched ? 'لم يتم العثور على تلفاز' : 'لم يبدأ البحث بعد', subtitle: searched ? 'اضغط تحديث أو أدخل العنوان يدوياً.' : null),
          for (final tv in found)
            Cell(
              icon: CupertinoIcons.tv_fill,
              iconColor: tv.ready ? Tokens.success : Tokens.gray,
              title: tv.name,
              subtitle: tv.host,
              trailing: tv.ready ? const Pill(text: 'جاهز', color: Tokens.success) : null,
              chevron: true,
              onTap: () => selectTv(tv.host, tv.name),
            ),
          Cell(title: 'تحديث البحث', titleColor: Tokens.accent, onTap: searching ? null : search),
        ],
      ),
      const GroupHeader('إدخال العنوان يدوياً'),
      Glass(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: manualController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'مثال: 192.168.1.40', errorText: manualError),
              onSubmitted: (_) => useManual(),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: useManual, child: const Text('استخدام هذا العنوان')),
          ],
        ),
      ),
      GroupFooter(android
          ? 'عنوان التلفاز يظهر في الإعدادات › الشبكة والإنترنت ضمن تفاصيل شبكة Wi-Fi الحالية. '
              '${phone == null ? '' : 'عنوان الهاتف $phone ويجب أن يتطابق مع التلفاز في أول ثلاث خانات.'}'
          : 'عنوان التلفاز يظهر في الإعدادات › الشبكة › Wi-Fi. '
              '${phone == null ? '' : 'عنوان الهاتف $phone ويجب أن يتطابق مع التلفاز في أول ثلاث خانات.'}'),
      if (android) ...[
        const SizedBox(height: 16),
        GlowButton(
          label: 'عرض الخطوات',
          icon: CupertinoIcons.list_number,
          onPressed: () {
            setState(() => guideIndex = 0);
            go(_Step.guide);
          },
        ),
      ],
    ];
  }

  // ----- 3. Developer guide
  List<Widget> guideView() {
    final steps = guideSteps;
    final index = guideIndex.clamp(0, steps.length - 1);
    final s = steps[index];
    final done = stepDone(s);
    final waiting = s.check != _Check.none && !done;
    return [
      progress(2, kind == TvKind.android ? 'تفعيل تصحيح الأخطاء' : 'تفعيل وضع المطوّر'),
      Glass(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: done ? Tokens.success : Tokens.accent, shape: BoxShape.circle),
                  child: done
                      ? const Icon(CupertinoIcons.checkmark_alt, size: 20, color: Colors.white)
                      : Text('${index + 1}', style: Txt.headline.copyWith(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(s.title, style: Txt.title3)),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 46),
              child: Text('الخطوة ${index + 1} من ${steps.length}', style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
            ),
            const SizedBox(height: 14),
            Text(s.body, style: Txt.callout),
            if (s.copy != null) ...[
              const SizedBox(height: 12),
              Glass(
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: SelectableText(s.copy!, style: Txt.subhead.copyWith(fontWeight: FontWeight.w600))),
                    IconButton(
                      tooltip: 'نسخ',
                      icon: const Icon(CupertinoIcons.doc_on_clipboard, color: Tokens.accent),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: s.copy!));
                        toast(context, 'تم نسخ الرابط');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      if (s.check != _Check.none) ...[
        const SizedBox(height: 12),
        done
            ? Notice(
                icon: CupertinoIcons.checkmark_circle_fill,
                color: Tokens.success,
                compact: true,
                text: s.check == _Check.keyServer ? 'Key Server مفعّل. يمكنك المتابعة.' : 'التلفاز جاهز. يمكنك المتابعة.',
              )
            : Glass(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        host == null ? 'جارٍ البحث عن التلفاز في الشبكة…' : 'بانتظار التلفاز ($host)…',
                        style: Txt.subhead.copyWith(color: Tokens.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
      ],
      if (s.different != null) ...[
        const SizedBox(height: 12),
        _Expandable(title: 'إذا كانت القائمة مختلفة', text: s.different!),
      ],
      const SizedBox(height: 18),
      GlowButton(
        label: waiting ? 'تم التنفيذ' : (index + 1 < steps.length ? 'تم التنفيذ' : 'الانتقال للتثبيت'),
        icon: CupertinoIcons.checkmark_alt,
        onPressed: (s.check == _Check.ready && host == null && waiting) ? null : nextGuide,
      ),
      if (s.check == _Check.ready && host == null && waiting)
        const GroupFooter('بانتظار ظهور التلفاز على الشبكة. إذا لم يظهر ارجع وأدخل عنوان IP يدوياً.'),
    ];
  }

  // ----- 4. Install
  List<Widget> installView() {
    final current = kind!;
    final failure = result != null && !result!.ok ? result : null;
    final text = failure == null ? null : tvErrorText(failure.error, current);
    return [
      progress(3, 'التثبيت'),
      Group(
        inset: 60,
        children: [
          Cell(icon: CupertinoIcons.tv_fill, iconColor: Tokens.purple, title: tvName.isEmpty ? current.title : tvName, subtitle: host),
          Cell(icon: CupertinoIcons.cube_box_fill, iconColor: Tokens.indigo, title: 'الإصدار المرفق', value: bundled[current] ?? '?'),
        ],
      ),
      if (current == TvKind.lg && needsPassphrase) ...[
        const GroupHeader('رمز المرور الظاهر على التلفاز'),
        Glass(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: passController,
                enabled: !installing,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                maxLength: 10,
                style: Txt.title2.copyWith(letterSpacing: 6),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: 'مثال: 2FEEB2', counterText: ''),
                onSubmitted: (_) => install(),
              ),
            ],
          ),
        ),
        const GroupFooter('رمز "Passphrase" المكوّن من 6 أحرف أسفل يسار شاشة Developer Mode عند تفعيل Key Server. يُطلب في الإعداد الأول فقط.'),
      ],
      if (current == TvKind.android && !installing && failure == null)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Notice(
            icon: CupertinoIcons.hand_raised_fill,
            title: 'ستظهر رسالة سماح على التلفاز',
            text: 'عند ظهور رسالة السماح بتصحيح الأخطاء على التلفاز، اختر "السماح دائماً من هذا الجهاز" ثم "سماح". تظهر غالباً في التثبيت الأول.',
          ),
        ),
      if (installing) ...[
        const SizedBox(height: 14),
        Glass(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tvStageText(stage), style: Txt.headline)),
                ],
              ),
              if (stage.startsWith('uploading:')) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: (int.tryParse(stage.substring(10)) ?? 0) / 100, borderRadius: BorderRadius.circular(4)),
              ],
            ],
          ),
        ),
        if (stage == 'approve') ...[
          const SizedBox(height: 12),
          const Notice(
            icon: CupertinoIcons.tv,
            color: Tokens.warning,
            title: 'انظر إلى شاشة التلفاز الآن',
            text: 'يطلب التلفاز تأكيد السماح بتصحيح الأخطاء. حدد "السماح دائماً من هذا الجهاز" واختر "سماح" ليستمر التثبيت تلقائياً.',
          ),
        ],
        const SizedBox(height: 10),
        const GroupFooter('أبقِ شاشة الهاتف مضاءة ومتصلة بالشبكة. يستغرق التثبيت أقل من دقيقة غالباً.'),
      ],
      if (failure != null) ...[
        const SizedBox(height: 14),
        Notice(icon: CupertinoIcons.exclamationmark_triangle_fill, color: Tokens.danger, title: text!.title, text: text.fix),
        if ((failure.detail ?? '').isNotEmpty && failure.error != 'CANCELLED') ...[
          const SizedBox(height: 10),
          _Expandable(title: 'تفاصيل الخطأ من التلفاز', text: failure.detail!),
        ],
      ],
      const SizedBox(height: 18),
      if (installing)
        OutlinedButton(onPressed: TvBridge.cancel, child: const Text('إلغاء'))
      else ...[
        GlowButton(
          icon: failure == null ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_clockwise,
          label: failure == null ? 'تثبيت على التلفاز' : 'إعادة المحاولة',
          onPressed: install,
        ),
        if (failure != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() => guideIndex = failure.error == 'KEY_SERVER_OFF' ? guideSteps.length - 1 : 0);
              go(_Step.guide);
            },
            child: const Text('العودة للخطوات'),
          ),
        ],
      ],
    ];
  }

  // ----- 5. Done
  List<Widget> doneView() {
    final r = result!;
    return [
      const SizedBox(height: 24),
      const Center(child: Icon(CupertinoIcons.checkmark_seal_fill, size: 84, color: Tokens.success)),
      const SizedBox(height: 16),
      Center(child: Text(r.installed ? 'تم تثبيت تطبيق التلفاز' : 'تطبيق التلفاز محدّث بالفعل', style: Txt.title2, textAlign: TextAlign.center)),
      const SizedBox(height: 6),
      Center(child: Text('الإصدار ${r.version ?? '?'}', style: Txt.subhead.copyWith(color: Tokens.textSecondary))),
      const SizedBox(height: 22),
      Notice(
        icon: CupertinoIcons.tv_fill,
        color: r.launched ? Tokens.success : Tokens.accent,
        title: r.launched ? 'تم تشغيل GameTranslator على التلفاز' : 'افتح GameTranslator على التلفاز',
        text: r.launched
            ? 'عند بدء الترجمة من الهاتف سيتصل تطبيق التلفاز بالهاتف تلقائياً عبر الشبكة.'
            : 'افتح GameTranslator من قائمة التطبيقات على التلفاز، وعند بدء الترجمة من الهاتف سيتصل به تلقائياً.',
      ),
      if (kind == TvKind.lg) ...[
        const SizedBox(height: 12),
        Notice(
          icon: CupertinoIcons.clock_fill,
          color: Tokens.warning,
          title: 'مدة جلسة وضع المطوّر في LG',
          text: '${r.hoursLeft != null ? 'الوقت المتبقي: ${r.hoursLeft} ساعة. ' : ''}بعد انتهاء المدة يُزال التطبيق تلقائياً. يمكنك الضغط على "EXTEND" في تطبيق Developer Mode أو إعادة التثبيت من هنا لتجديد المدة.',
        ),
      ],
      if (kind == TvKind.android) ...[
        const SizedBox(height: 12),
        const Notice(
          icon: CupertinoIcons.info_circle_fill,
          text: 'يمكنك إيقاف تصحيح الأخطاء بعد الانتهاء إذا رغبت، وستحتاج لتفعيله مجدداً عند تثبيت تحديث لاحق.',
        ),
      ],
      const SizedBox(height: 22),
      GlowButton(label: 'تم', onPressed: () => Navigator.of(context).pop()),
    ];
  }
}

bool _newer(String a, String b) {
  List<int> parts(String v) => v.split(RegExp(r'[.-]')).map((p) => int.tryParse(p) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final l = i < x.length ? x[i] : 0, r = i < y.length ? y[i] : 0;
    if (l != r) return l > r;
  }
  return false;
}

class _Numbered extends StatelessWidget {
  const _Numbered(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Tokens.accentSoft, shape: BoxShape.circle),
              child: Text('$number', style: Txt.footnote.copyWith(fontWeight: FontWeight.w700, color: Tokens.accent)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Txt.subhead)),
          ],
        ),
      );
}

/// Expandable explanation card.
class _Expandable extends StatefulWidget {
  const _Expandable({required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  bool open = false;

  @override
  Widget build(BuildContext context) => Glass(
        radius: 18,
        clip: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Cell(
              icon: CupertinoIcons.question_circle_fill,
              iconColor: Tokens.gray,
              title: widget.title,
              trailing: Icon(open ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, size: 16, color: Tokens.textSecondary),
              onTap: () => setState(() => open = !open),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SelectableText(widget.text, style: Txt.subhead.copyWith(color: const Color(0xD9EBEBF5))),
              ),
          ],
        ),
      );
}
