// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'bridge.dart';
import 'home_page.dart';
import 'intro_page.dart';
import 'main.dart';
import 'tv_install_page.dart';
import 'ui.dart';

/// Settings tab, laid out like iOS Settings: translation, subtitle region, TV appearance, PS5, and about.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.setup, required this.onSetupChanged, required this.active});

  final SetupInfo setup;
  final Future<void> Function() onSetupChanged;

  /// Whether the tab is visible; game snapshots are not requested in the background.
  final bool active;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const languages = {
    'ar': 'العربية',
    'en': 'الإنجليزية',
    'de': 'الألمانية',
    'fr': 'الفرنسية',
    'es': 'الإسبانية',
    'it': 'الإيطالية',
    'pt': 'البرتغالية',
    'ru': 'الروسية',
    'ja': 'اليابانية',
  };

  static const flags = {
    'ar': '🇸🇦',
    'en': '🇬🇧',
    'de': '🇩🇪',
    'fr': '🇫🇷',
    'es': '🇪🇸',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'ja': '🇯🇵',
  };

  static const placements = {
    'cover': 'تغطية ترجمة اللعبة',
    'above': 'فوق ترجمة اللعبة',
    'below': 'أسفل ترجمة اللعبة',
    'fixed': 'ثابت أسفل الشاشة',
  };

  static const edges = {'top': 'أعلى', 'bottom': 'أسفل', 'left': 'يسار', 'right': 'يمين'};
  static const defaultRegion = {'top': 0.62, 'bottom': 0.97, 'left': 0.14, 'right': 0.86};

  AppSettings? settings;
  final deepLController = TextEditingController();
  Uint8List? preview;
  Timer? saveTimer;
  Timer? previewTimer;

  /// Active edge controlled by the slider in the subtitle region editor.
  String edge = 'top';

  @override
  void initState() {
    super.initState();
    load();
    // Keep the game frame preview updated while adjusting the region.
    previewTimer = Timer.periodic(const Duration(seconds: 2), (_) => refreshPreview());
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    previewTimer?.cancel();
    final current = settings;
    if (current != null) Bridge.saveSettings(current);
    deepLController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final loaded = await Bridge.settings();
    final image = await Bridge.snapshot(width: 640);
    if (!mounted) return;
    setState(() {
      settings = loaded;
      preview = image;
      deepLController.text = loaded.deepLKey;
    });
  }

  Future<void> refreshPreview() async {
    if (!mounted || !widget.active) return;
    final image = await Bridge.snapshot(width: 640);
    if (mounted && image != null) setState(() => preview = image);
  }

  /// Applies changes immediately in UI and debounces persistence while dragging sliders.
  void change(void Function(AppSettings) edit) {
    final current = settings;
    if (current == null) return;
    setState(() => edit(current));
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 300), () => Bridge.saveSettings(current));
  }

  void setRegion(String edge, double value) => change((s) {
        final region = s.region;
        region[edge] = value;
        // Ensure region keeps at least 5% height and width.
        if (edge == 'top' && region['bottom'] < value + 0.05) region['bottom'] = (value + 0.05).clamp(0.0, 1.0);
        if (edge == 'bottom' && region['top'] > value - 0.05) region['top'] = (value - 0.05).clamp(0.0, 1.0);
        if (edge == 'left' && region['right'] < value + 0.05) region['right'] = (value + 0.05).clamp(0.0, 1.0);
        if (edge == 'right' && region['left'] > value - 0.05) region['left'] = (value - 0.05).clamp(0.0, 1.0);
        s.json['region'] = region;
      });

  void setStyle(String key, Object value) => change((s) {
        final style = s.style;
        style[key] = value;
        s.json['style'] = style;
      });

  Future<void> pickLanguage(String key, String title) async {
    final picked = await showApplePicker(context, title: title, options: languages, selected: settings?.json[key] as String?, leading: flags);
    if (picked != null) change((s) => s.json[key] = picked);
  }

  Future<void> pickPlacement() async {
    final picked = await showApplePicker(context, title: 'موضع الترجمة', options: placements, selected: settings?.style['placement'] as String?);
    if (picked != null) setStyle('placement', picked);
  }

  Future<void> editGlossary() async {
    final current = settings;
    if (current == null) return;
    final text = await Navigator.of(context).push<String>(appleRoute((_) => GlossaryPage(initial: current.glossary)));
    if (text != null) change((s) => s.json['glossary'] = text);
  }

  Future<void> sendTest() async {
    await Bridge.testSubtitle();
    if (mounted) toast(context, 'تم إرسال الترجمة التجريبية.');
  }

  Future<void> confirmForget({required bool account}) async {
    final confirmed = await confirmApple(
      context,
      title: account ? 'تغيير حساب PSN؟' : 'إعادة ربط جهاز PS5؟',
      message: account
          ? 'سيتم حذف الحساب المحفوظ وربط PS5؛ وستحتاج لإعادة الإعداد من البداية.'
          : 'سيتم حذف الربط الحالي؛ ويمكنك إعادة الربط باستخدام رمز "إقران الجهاز" في PS5.',
      action: 'حذف ومتابعة',
      destructive: true,
    );
    if (!confirmed) return;
    await Bridge.stop();
    if (account) {
      await Bridge.forgetAccount();
    } else {
      await Bridge.forgetConsole();
    }
    await widget.onSetupChanged();
  }

  void showIntro() {
    Navigator.of(context).push(appleRoute<void>((context) => IntroPage(replay: true, onDone: () async => Navigator.of(context).pop())));
  }

  Future<void> showLogs() async {
    final lines = await Bridge.logs();
    if (!mounted) return;
    final text = lines.isEmpty ? 'لا توجد سجلات بعد.' : lines.reversed.join('\n');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (sheet, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(child: Text('السجل', style: Txt.title2)),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.of(sheet).pop();
                    toast(context, 'تم نسخ السجل.');
                  },
                  child: const Text('نسخ'),
                ),
              ],
            ),
            Text('يمكنك مشاركة هذه السجلات للمساعدة في حل المشاكل.', style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
            const SizedBox(height: 12),
            SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Tokens.textSecondary, height: 1.45)),
          ],
        ),
      ),
    );
  }

  String get glossarySummary {
    final (terms, keep, problem) = GlossaryPage.inspect(settings?.glossary ?? '');
    if (problem != null) return 'خطأ';
    if (terms + keep == 0) return 'فارغ';
    return '${terms + keep} مصطلح';
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    if (s == null) return const Center(child: CupertinoActivityIndicator(radius: 14));
    final style = s.style;
    return LargeTitleList(
      title: 'الإعدادات',
      children: [
        // ---------------------------------------------------------------- Translation
        const GroupHeader('الترجمة'),
        Group(
          inset: 60,
          children: [
            Cell(
              icon: CupertinoIcons.gamecontroller_fill,
              iconColor: Tokens.indigo,
              title: 'لغة اللعبة',
              value: '${flags[s.sourceLanguage] ?? ''} ${languages[s.sourceLanguage] ?? s.sourceLanguage}',
              chevron: true,
              onTap: () => pickLanguage('sourceLanguage', 'لغة اللعبة'),
            ),
            Cell(
              icon: CupertinoIcons.globe,
              iconColor: Tokens.accent,
              title: 'لغة الترجمة',
              value: '${flags[s.targetLanguage] ?? ''} ${languages[s.targetLanguage] ?? s.targetLanguage}',
              chevron: true,
              onTap: () => pickLanguage('targetLanguage', 'لغة الترجمة'),
            ),
            if (s.sourceLanguage == 'en' && s.targetLanguage == 'ar')
              Cell(
                icon: CupertinoIcons.book_fill,
                iconColor: Tokens.warning,
                title: 'قاموس المصطلحات',
                value: glossarySummary,
                chevron: true,
                onTap: editGlossary,
              ),
            if (s.sourceLanguage == 'en' && s.targetLanguage == 'ar')
              Cell(
                icon: CupertinoIcons.cube_box_fill,
                iconColor: Tokens.success,
                title: 'حزم الألعاب',
                subtitle: 'ترجمة جاهزة لألعاب مثل GTA V و RDR2 و Elden Ring',
                trailing: CupertinoSwitch(
                  value: s.packsEnabled,
                  activeTrackColor: Tokens.success,
                  onChanged: (value) => change((s) => s.json['packsEnabled'] = value),
                ),
              ),
          ],
        ),
        if (s.sourceLanguage == 'en' && s.targetLanguage == 'ar')
          const GroupFooter('الأسطر الموجودة في حزمة اللعبة تُعرض مباشرة دون استهلاك محرك الترجمة. '
              'يتم تحديث الحزم أسبوعياً.'),
        const GroupHeader('محرك الترجمة'),
        Group(
          children: [
            Cell(
              title: 'Google',
              subtitle: 'يتطلب اتصالاً بالإنترنت ولا يحتاج مفتاح API. موصى به لمعظم الألعاب.',
              checked: s.engine == 'google',
              onTap: () => change((s) => s.json['engine'] = 'google'),
            ),
            Cell(
              title: 'DeepL',
              subtitle: 'صياغة أكثر طبيعية؛ يعمل بمفتاح DeepL API الخاص بك.',
              checked: s.engine == 'deepl',
              onTap: () => change((s) => s.json['engine'] = 'deepl'),
            ),
            if (s.engine == 'deepl')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: TextField(
                  controller: deepLController,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'مفتاح DeepL API'),
                  onChanged: (value) => change((s) => s.json['deepLKey'] = value.trim()),
                ),
              ),
            Cell(
              title: 'على الجهاز (بدون إنترنت)',
              subtitle: 'يعمل دون إنترنت بدقة أقل. يتم تحميل نموذج اللغة مرة واحدة.',
              checked: s.engine == 'mlkit',
              onTap: () => change((s) => s.json['engine'] = 'mlkit'),
            ),
          ],
        ),
        const GroupFooter('عند انقطاع الإنترنت تنتقل الترجمة تلقائياً إلى النموذج المحلي. إذا كان مفتاح DeepL فارغاً أو معطلاً يُستخدم Google.'),

        // ---------------------------------------------------------------- Subtitle region
        const GroupHeader('منطقة الترجمة'),
        Glass(
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (preview != null) RegionPreview(image: preview!, settings: s) else _RegionPlaceholder(settings: s),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: CupertinoSlidingSegmentedControl<String>(
                  groupValue: edge,
                  backgroundColor: Tokens.inset,
                  thumbColor: const Color(0xFF636366),
                  children: {
                    for (final entry in edges.entries)
                      entry.key: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(entry.value, style: Txt.subhead.copyWith(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w500)),
                      ),
                  },
                  onValueChanged: (value) => setState(() => edge = value ?? edge),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSlider(
                        value: s.regionValue(edge).clamp(0.0, 1.0),
                        activeColor: Tokens.accent,
                        onChanged: (value) => setRegion(edge, (value * 100).round() / 100),
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Text('%${(s.regionValue(edge) * 100).round()}', textAlign: TextAlign.end, style: Txt.body.copyWith(color: Tokens.textSecondary)),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Cell(title: 'استعادة الافتراضي', titleColor: Tokens.accent, onTap: () => change((s) => s.json['region'] = Map<String, dynamic>.from(defaultRegion))),
            ],
          ),
        ),
        const GroupFooter('حرّك الإطار الأزرق فوق مكان ظهور الترجمة في اللعبة. إذا كان الإطار ضيقاً قد تُقتطع بداية الجملة أو نهايتها.'),

        // ---------------------------------------------------------------- TV appearance
        const GroupHeader('المظهر على التلفاز'),
        Group(
          children: [
            _ControlRow(
              title: 'حجم الخط',
              child: _Segmented(
                value: '${style['fontSize']}',
                items: const {'36': 'صغير', '46': 'متوسط', '58': 'كبير', '72': 'ضخم'},
                onChanged: (value) => setStyle('fontSize', int.parse(value)),
              ),
            ),
            _ControlRow(
              title: 'لون الخط',
              child: _Segmented(
                value: style['textColor'] as String,
                items: const {'white': 'أبيض', 'yellow': 'أصفر'},
                onChanged: (value) => setStyle('textColor', value),
              ),
            ),
            Cell(
              title: 'موضع الترجمة',
              subtitle: placements[style['placement']] ?? '',
              chevron: true,
              onTap: pickPlacement,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('تعتيم الخلفية', style: Txt.body)),
                      Text('%${style['background']}', style: Txt.body.copyWith(color: Tokens.textSecondary)),
                    ],
                  ),
                  CupertinoSlider(
                    value: (style['background'] as num).toDouble().clamp(0, 100),
                    max: 100,
                    divisions: 20,
                    activeColor: Tokens.accent,
                    onChanged: (value) => setStyle('background', value.round()),
                  ),
                ],
              ),
            ),
            Cell(
              title: 'خط عريض',
              trailing: CupertinoSwitch(value: style['bold'] as bool, activeTrackColor: Tokens.success, onChanged: (value) => setStyle('bold', value)),
            ),
            Cell(title: 'إرسال ترجمة تجريبية للتلفاز', titleColor: Tokens.accent, onTap: sendTest),
          ],
        ),

        // ---------------------------------------------------------------- TV app
        const GroupHeader('تطبيق التلفاز'),
        Group(
          inset: 60,
          children: [
            Cell(
              icon: CupertinoIcons.tv_fill,
              iconColor: Tokens.purple,
              title: 'تثبيت تطبيق التلفاز',
              subtitle: 'التثبيت أو التحديث على Android TV و LG من الهاتف',
              chevron: true,
              onTap: () => Navigator.of(context).push(appleRoute<void>((_) => const TvInstallPage())),
            ),
          ],
        ),

        // ---------------------------------------------------------------- PS5
        const GroupHeader('PS5'),
        Group(
          inset: 60,
          children: [
            Cell(
              icon: CupertinoIcons.gamecontroller_fill,
              iconColor: Tokens.gray,
              title: widget.setup.consoleName ?? 'PS5',
              subtitle: widget.setup.consoleHost ?? '',
              trailing: const Pill(text: 'متطابق', color: Tokens.success),
            ),
            Cell(
              icon: CupertinoIcons.power,
              iconColor: Tokens.success,
              title: 'إيقاظ من وضع السكون',
              trailing: CupertinoSwitch(
                value: s.autoWake,
                activeTrackColor: Tokens.success,
                onChanged: (value) => change((s) => s.json['autoWake'] = value),
              ),
            ),
          ],
        ),
        const GroupFooter('يتم تشغيل PS5 تلقائياً عند بدء الترجمة إذا كان في وضع السكون.'),
        const SizedBox(height: 14),
        Group(
          children: [
            Cell(title: 'إعادة ربط PS5', titleColor: Tokens.accent, onTap: () => confirmForget(account: false)),
            Cell(title: 'تغيير حساب PSN', titleColor: Tokens.danger, onTap: () => confirmForget(account: true)),
          ],
        ),

        // ---------------------------------------------------------------- About
        const GroupHeader('حول التطبيق'),
        Group(
          inset: 60,
          children: [
            Cell(icon: CupertinoIcons.play_circle_fill, iconColor: Tokens.purple, title: 'عرض المقدمة', chevron: true, onTap: showIntro),
            Cell(icon: CupertinoIcons.doc_text_fill, iconColor: Tokens.gray, title: 'السجل', chevron: true, onTap: showLogs),
            Cell(
              icon: CupertinoIcons.info,
              iconColor: Tokens.accent,
              title: 'الإصدار',
              value: widget.setup.version.isEmpty ? '—' : widget.setup.version,
            ),
          ],
        ),
        const GroupFooter(
          'تبقى صورة اللعبة وبيانات حسابك على هاتفك. عند اختيار محرك ترجمة عبر الإنترنت يتم إرسال نص الترجمة المقروء فقط '
          'إلى خدمة الترجمة.\n\nGameTranslator مفتوح المصدر (AGPL-3.0). غير تابع لشركة Sony أو PlayStation.',
        ),
      ],
    );
  }
}

/// Row with title above and control below (for segmented controls).
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(title, style: Txt.body), const SizedBox(height: 10), child],
      ),
    );
  }
}

/// Sliding segmented control.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.items, required this.onChanged});

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<String>(
      groupValue: items.containsKey(value) ? value : null,
      backgroundColor: Tokens.inset,
      thumbColor: const Color(0xFF636366),
      children: {
        for (final entry in items.entries)
          entry.key: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(entry.value, style: Txt.subhead.copyWith(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w500)),
          ),
      },
      onValueChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

/// Placeholder shown when translation is stopped and no game frame is available.
class _RegionPlaceholder extends StatelessWidget {
  const _RegionPlaceholder({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black)),
            Positioned(
              left: 0,
              right: 0,
              top: 18,
              child: Text('تظهر صورة اللعبة هنا عند تشغيل الترجمة.', textAlign: TextAlign.center, style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
            ),
            Positioned(
              left: settings.regionValue('left') * constraints.maxWidth,
              top: settings.regionValue('top') * constraints.maxHeight,
              width: (settings.regionValue('right') - settings.regionValue('left')) * constraints.maxWidth,
              height: (settings.regionValue('bottom') - settings.regionValue('top')) * constraints.maxHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Tokens.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                  color: Tokens.accent.withValues(alpha: 0.12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glossary editor using the same JSON structure as the desktop dictionary files.
class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key, required this.initial});

  final String initial;

  static const example = '{\n  "terms": {\n    "Leviathan Axe": "فأس ليفياثان"\n  },\n  "keep": ["Kratos", "Atreus"]\n}';

  /// Returns term count, kept name count, and an error message if invalid.
  static (int, int, String?) inspect(String text) {
    if (text.trim().isEmpty) return (0, 0, null);
    try {
      final root = jsonDecode(text);
      if (root is! Map) return (0, 0, 'يجب أن يكون القاموس بصيغة { ... }.');
      final terms = root['terms'] is Map ? (root['terms'] as Map).values.whereType<String>().length : 0;
      final keep = root['keep'] is List ? (root['keep'] as List).whereType<String>().length : 0;
      return (terms, keep, null);
    } on FormatException {
      return (0, 0, 'خطأ في الصياغة: تأكد من علامات التنصيص والفواصل والأقواس.');
    }
  }

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (terms, keep, problem) = GlossaryPage.inspect(controller.text);
    final empty = controller.text.trim().isEmpty;
    return GlassScaffold(
      title: 'قاموس المصطلحات',
      actions: [
        TextButton(
          onPressed: problem == null ? () => Navigator.of(context).pop(controller.text.trim()) : null,
          child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'يمكنك تثبيت ترجمة الأسماء الخاصة ومصطلحات الألعاب هنا. '
              'المصطلحات داخل "terms" تُترجم كما تكتبها، والأسماء داخل "keep" تبقى كما هي.',
              style: Txt.subhead.copyWith(color: Tokens.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 10,
            maxLines: 22,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.45),
            decoration: InputDecoration(
              hintText: GlossaryPage.example,
              hintMaxLines: 8,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Tokens.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Tokens.border)),
            ),
          ),
          const SizedBox(height: 12),
          if (problem != null)
            Notice(icon: CupertinoIcons.exclamationmark_circle_fill, color: Tokens.danger, text: problem)
          else if (empty)
            Notice(
              icon: CupertinoIcons.wand_stars,
              text: 'القاموس فارغ. يمكنك البدء بمثال وتعديله بمصطلحاتك.',
              action: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                onPressed: () => setState(() => controller.text = GlossaryPage.example),
                child: const Text('إضافة مثال'),
              ),
            )
          else
            Notice(icon: CupertinoIcons.checkmark_circle_fill, color: Tokens.success, text: 'تمت قراءة $terms مصطلح و $keep اسم محفوظ.'),
          const GroupFooter(
            'يطابق صيغة ملفات القاموس في نسخة الحاسوب؛ يمكنك لصق محتواها هنا. '
            'يُستخدم في الترجمة من الإنجليزية إلى العربية.',
          ),
        ],
      ),
    );
  }
}
