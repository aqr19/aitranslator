// SPDX-License-Identifier: AGPL-3.0-only
import 'package:material_ui/material_ui.dart';

import 'bridge.dart';
import 'main.dart';
import 'tv_install_page.dart';
import 'ui.dart';

/// Detailed user guide: from PS5 preparation to troubleshooting, organized into chapters.
class GuideChapter {
  const GuideChapter({required this.icon, required this.color, required this.title, required this.subtitle, required this.children});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;
}

/// Guide tab: grouped list of chapters.
class GuideTab extends StatelessWidget {
  const GuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitleList(
      title: 'الدليل',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('كل شيء بدءاً من الإعداد وحتى استكشاف الأخطاء وإصلاحها، خطوة بخطوة.', style: Txt.body.copyWith(color: Tokens.textSecondary)),
        ),
        const GuideList(),
      ],
    );
  }
}

/// Grouped chapter list; tapping a row opens its chapter page.
class GuideList extends StatelessWidget {
  const GuideList({super.key});

  @override
  Widget build(BuildContext context) {
    final chapters = guideChapters(null);
    Widget cell(int index) => Cell(
          icon: chapters[index].icon,
          iconColor: chapters[index].color,
          title: chapters[index].title,
          subtitle: chapters[index].subtitle,
          chevron: true,
          onTap: () => Navigator.of(context).push(appleRoute<void>((_) => GuideChapterPage(index: index))),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupHeader('البداية'),
        Group(inset: 60, children: [for (var i = 0; i < 5; i++) cell(i)]),
        const GroupHeader('الاستخدام'),
        Group(inset: 60, children: [for (var i = 5; i < 8; i++) cell(i)]),
        const GroupHeader('المساعدة'),
        Group(inset: 60, children: [cell(8)]),
      ],
    );
  }
}

/// Single chapter page.
class GuideChapterPage extends StatefulWidget {
  const GuideChapterPage({super.key, required this.index});

  final int index;

  @override
  State<GuideChapterPage> createState() => _GuideChapterPageState();
}

class _GuideChapterPageState extends State<GuideChapterPage> {
  String? address;

  @override
  void initState() {
    super.initState();
    Bridge.state().then((state) {
      if (mounted) setState(() => address = state.localAddress);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapters = guideChapters(address);
    final chapter = chapters[widget.index];
    final next = widget.index + 1 < chapters.length ? widget.index + 1 : null;
    return GlassScaffold(
      title: 'الدليل',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Row(
              children: [
                IconTile(chapter.icon, chapter.color, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chapter.title, style: Txt.title2),
                      Text(chapter.subtitle, style: Txt.subhead.copyWith(color: Tokens.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Glass(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: chapter.children),
          ),
          if (next != null) ...[
            const GroupHeader('الفصل التالي'),
            Group(
              inset: 60,
              children: [
                Cell(
                  icon: chapters[next].icon,
                  iconColor: chapters[next].color,
                  title: chapters[next].title,
                  subtitle: chapters[next].subtitle,
                  chevron: true,
                  onTap: () => Navigator.of(context).pushReplacement(appleRoute<void>((_) => GuideChapterPage(index: next))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Chapter definitions. [address] provides the phone's local IP for OBS browser source examples.
List<GuideChapter> guideChapters(String? address) {
  final phone = address ?? 'عنوان_الهاتف';
  return [
    const GuideChapter(
      icon: CupertinoIcons.arrow_right_arrow_left,
      color: Tokens.accent,
      title: 'كيف يعمل؟',
      subtitle: 'آلية العمل في لمحة',
      children: [
        _P('يربط GameTranslator بين ثلاثة أجهزة: تعمل اللعبة على PS5 وتعرض على التلفاز، بينما يتولى الهاتف قراءة النصوص وترجمتها:'),
        _Steps([
          'يستقبل الهاتف بث صورة اللعبة من PS5 عبر اللعب عن بُعد (Remote Play) دون استخدام الكاميرا.',
          'يقرأ المنطقة المحددة في الصورة التي تظهر فيها الترجمة ويترجم النص.',
          'يرسل الترجمة إلى التلفاز عبر نفس شبكة Wi-Fi ليعرضها تطبيق GameTranslator فوق اللعبة.',
        ]),
        _Sub('ما الذي تحتاجه؟'),
        _Bullets([
          'حساب مستخدم ثانٍ على PS5 كما هو موضح في الفصل التالي.',
          'تلفاز مثبت عليه تطبيق GameTranslator TV: LG أو Samsung أو Android TV / Google TV.',
          'شبكة Wi-Fi واحدة تجمع الهاتف وجهاز PS5 والتلفاز.',
          'اتصال إنترنت للترجمة السحابية، أو استخدام خيار الترجمة بدون إنترنت.',
        ]),
        _Tip('يتم الإعداد مرة واحدة، وبعدها يكفي بدء الترجمة من الهاتف وفتح التطبيق على التلفاز.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.gamecontroller_fill,
      color: Tokens.indigo,
      title: 'تجهيز PS5',
      subtitle: 'المستخدم الثاني واللعب عن بُعد',
      children: [
        _Sub('1. أضف مستخدماً ثانياً'),
        _P('يتعامل PS5 مع جهاز اللعب عن بُعد كأنه يد تحكم مرتبطة بذلك الحساب. لو دخل الهاتف بحسابك الأساسي فسينفصل '
            'الذراع الذي بيدك عن التلفاز، لذلك نربط الهاتف بحساب ثانوي لتستمر أنت باللعب بحسابك الأساسي.'),
        _Steps([
          'أضف مستخدماً جديداً على PS5 (تبديل المستخدم › إضافة مستخدم من صورة الحساب في الشاشة الرئيسية).',
          'سجّل الدخول لهذا المستخدم بحساب PSN (يمكن إنشاء حساب مجاني ولا يلزم اشتراك PS Plus).',
          'ستستخدم نفس هذا الحساب الثانوي عند تسجيل الدخول على الهاتف.',
        ]),
        _Sub('2. فعّل اللعب عن بُعد'),
        _Steps([
          'بدّل إلى المستخدم الثاني على PS5.',
          'ادخل إلى الإعدادات › النظام › اللعب عن بُعد.',
          'فعّل خيار "تمكين اللعب عن بُعد".',
        ]),
        _Sub('3. الإيقاظ من وضع السكون (اختياري)'),
        _P('حتى يتمكن الهاتف من إيقاظ PS5 تلقائياً عند بدء الترجمة وهو في وضع السكون:'),
        _Steps([
          'ادخل إلى الإعدادات › النظام › توفير الطاقة › الميزات المتوفرة في وضع السكون.',
          'فعّل "البقاء متصلاً بالإنترنت" و"تمكين تشغيل PS5 من الشبكة".',
        ]),
        _Tip('إذا لم ترغب في الإيقاظ التلقائي يمكنك إيقاف "إيقاظ من وضع السكون" من الإعدادات › PS5 في الهاتف.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.link,
      color: Tokens.success,
      title: 'إقران الهاتف مع PS5',
      subtitle: 'دخول PSN ورمز من 8 أرقام',
      children: [
        _Sub('1. تسجيل الدخول عبر PSN'),
        _Steps([
          'في شاشة الإعداد اضغط "تسجيل الدخول عبر PSN" لفتح صفحة تسجيل الدخول من Sony.',
          'سجّل الدخول بحساب المستخدم الثاني الموجود على PS5.',
          'بعد إتمام الدخول يعود التطبيق تلقائياً وتظهر حالة الحساب متصلة.',
        ]),
        _Tip('تُدخل كلمة المرور مباشرة في صفحة Sony، ولا يحتفظ التطبيق إلا بمعرّف الحساب.'),
        _Sub('2. إدخال رمز الاقتران'),
        _Steps([
          'وأنت على المستخدم الثاني في PS5، ادخل إلى الإعدادات › النظام › اللعب عن بُعد › "إقران الجهاز".',
          'سيظهر رمز من 8 أرقام وعد تنازلي على الشاشة (صالح لنحو 5 دقائق).',
          'اختر PS5 من قائمة "الأجهزة المكتشفة" على الهاتف.',
          'اكتب الرمز في المربعات واضغط "إقران".',
        ]),
        _Sub('إذا لم يظهر PS5 في القائمة'),
        _Bullets([
          'تأكد أن الهاتف و PS5 على نفس شبكة Wi-Fi (وليس شبكة ضيف أو بيانات الهاتف).',
          'اضغط "تحديث".',
          'إذا لم يظهر، اضغط "إدخال عنوان IP يدوياً" واكتب العنوان الظاهر في PS5 من الإعدادات › الشبكة › حالة الاتصال › عرض حالة الاتصال.',
        ]),
        _Tip('الاقتران يتم مرة واحدة، وإذا تغير عنوان IP لجهاز PS5 سيكتشفه التطبيق تلقائياً على الشبكة.'),
      ],
    ),
    GuideChapter(
      icon: CupertinoIcons.tv_fill,
      color: Tokens.purple,
      title: 'إعداد التلفاز',
      subtitle: 'الشاشات المدعومة وتثبيت تطبيق التلفاز',
      children: [
        const _P('يعرض تطبيق GameTranslator TV الترجمة على شاشة التلفاز. يمكنك تثبيته على Android TV / Google TV و LG من الهاتف مباشرة، بينما يتم التثبيت على Samsung من الحاسوب حالياً.'),
        const InstallTvButton(),
        const _Sub('ما الشاشات المدعومة؟'),
        const _Table([
          ('LG', 'webOS 4 فأحدث', true),
          ('Samsung', 'Tizen، 2019 فأحدث', true),
          ('Android TV / Google TV', 'TCL، Sony، Philips، Xiaomi وغيرها من أجهزة Android TV / Google TV', true),
          ('أنظمة أخرى', 'بعض أنظمة Linux المحدودة، Philips Saphi، Titan OS', false),
        ]),
        const _Tip('هل تلفازك Android / Google TV؟ إذا كانت الشاشة الرئيسية تعرض Google Play أو "Google TV" فهو كذلك.'),
        const _Sub('LG'),
        _Steps([
          'أنشئ حساب مطوّر LG مجاني عبر webostv.developer.lge.com.',
          'ثبّت تطبيق "Developer Mode" من LG Content Store على التلفاز، وسجّل الدخول ثم فعّل "Dev Mode Status" وأعد التشغيل.',
          'افتح "Key Server" داخل تطبيق Developer Mode على التلفاز.',
          'من معالج "تثبيت تطبيق التلفاز" على الهاتف اختر LG، وحدد التلفاز وأدخل رمز Passphrase المكوّن من 6 أحرف.',
        ]),
        const _P('تبقى جلسة وضع المطوّر في LG مفعّلة لفترة محدودة (حتى 1000 ساعة)، اضغط "EXTEND" في التطبيق قبل انتهائها أو أعد التثبيت من الهاتف.'),
        const _Sub('Samsung'),
        _Steps([
          'افتح شاشة التطبيقات على التلفاز واضغط الأزرار 1 2 3 4 5 بالريموت لفتح نافذة وضع المطوّر.',
          'فعّل "Developer mode" وأدخل عنوان IP الخاص بالحاسوب في "Host PC IP".',
          'أعد تشغيل التلفاز بالضغط المطوّل على زر التشغيل.',
          'من تطبيق GameTranslator على الحاسوب اختر شاشة Samsung وسجّل الدخول بحساب Samsung لتوقيع التطبيق وتثبيته.',
        ]),
        const _Sub('Android TV / Google TV'),
        _Steps([
          'في التلفاز: الإعدادات › تفضيلات الجهاز › حول (أو في Google TV: الإعدادات › النظام › حول).',
          'اضغط زر الموافق على رقم الإصدار 7 مرات لتفعيل خيارات المطوّر.',
          'فعّل "تصحيح أخطاء USB" (وتصحيح الأخطاء عبر الشبكة إن وجد) من خيارات المطوّر.',
          'من معالج "تثبيت تطبيق التلفاز" على الهاتف اختر Android TV / Google TV وأكّد رسالة السماح على التلفاز.',
        ]),
        const _P('إذا لم يتوفر تصحيح الأخطاء عبر الشبكة في جهازك، يمكنك تحميل ملف APK وتثبيته عبر فلاش USB ومدير الملفات على التلفاز.'),
        const _Sub('بعد التثبيت'),
        _P('يعثر تطبيق التلفاز على الهاتف تلقائياً عبر الشبكة المحلية دون الحاجة لإدخال عنوان IP للتلفاز في الهاتف.'),
        const _Sub('للمبثّين: OBS'),
        _P('أثناء تشغيل الترجمة تتوفر صفحة ويب مخصصة؛ أضف "Browser Source" في OBS بالرابط '
            'http://$phone:8787/obs بأبعاد (1920×1080) للبث والتسجيل.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.play_fill,
      color: Tokens.accent,
      title: 'أول تشغيل',
      subtitle: 'بدء الترجمة ومشاهدتها على التلفاز',
      children: [
        _Steps([
          'شغّل اللعبة على PS5 بحسابك الأساسي وفعّل الترجمة في إعدادات اللعبة.',
          'اضغط زر التشغيل الكبير في الشاشة الرئيسية على الهاتف (واسمح بالإشعارات في المرة الأولى لتعمل الترجمة في الخلفية).',
          'عند وصول الحالة إلى "الترجمة قيد التشغيل" ستظهر حالة PS5 "متصل".',
          'افتح تطبيق GameTranslator على التلفاز وخلال ثوانٍ ستظهر حالة التلفاز "متصل".',
          'إذا لم تظهر صورة اللعبة على التلفاز افتح اللوحة بالزر "موافق" وبدّل منفذ HDMI باليمين واليسار.',
          'اضغط "إرسال ترجمة تجريبية للتلفاز" للتأكد من وصول النص.',
        ]),
        _Tip('يمكنك إطفاء شاشة الهاتف أثناء التشغيل؛ لإيقاف الترجمة اضغط الزر في التطبيق أو "إيقاف" من الإشعار.'),
        _Sub('في المرات القادمة'),
        _P('خطوتان فقط: ابدأ الترجمة من الهاتف وافتح GameTranslator على التلفاز.'),
        _Sub('البطارية والحرارة'),
        _P('فك تشفير الفيديو وقراءة النصوص يستهلك موارد؛ يُفضّل توصيل الهاتف بالشاحن أثناء الجلسات الطويلة.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.dot_radiowaves_left_right,
      color: Tokens.gray,
      title: 'أزرار ريموت التلفاز',
      subtitle: 'الاختصارات داخل تطبيق التلفاز',
      children: [
        _P('عند فتح GameTranslator على التلفاز تعمل الأزرار كالتالي:'),
        _Keys([
          ('موافق (OK)', 'فتح وإغلاق لوحة الحالة (منفذ HDMI وحالة الاتصال).'),
          ('يسار / يمين', 'تبديل منفذ HDMI عندما تكون اللوحة مفتوحة.'),
          ('1 – 4', 'الانتقال المباشر إلى منفذ HDMI المحدد.'),
          ('أعلى / أسفل', 'تحريك موضع الترجمة للأعلى أو الأسفل على الشاشة.'),
          ('أحمر', 'عرض معلومات التلفاز.'),
          ('أخضر', 'فتح وإغلاق لوحة الحالة.'),
          ('أزرق', 'تشغيل أو إيقاف العرض التجريبي بترجمة نموذجية.'),
          ('رجوع (Back)', 'إغلاق التطبيق.'),
        ]),
        _Tip('اللعب يتم بذراع PS5؛ ريموت التلفاز يُستخدم لهذه الإعدادات فقط.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.crop,
      color: Tokens.teal,
      title: 'تحديد منطقة الترجمة',
      subtitle: 'ضبط الإطار على شاشة المعاينة',
      children: [
        _P('يقرأ الهاتف المنطقة المحددة فقط وليس الشاشة كاملة؛ إذا كان الإطار في غير مكانه فقد لا تظهر ترجمة أو تُترجم نصوص أخرى من الشاشة.'),
        _Steps([
          'أثناء تشغيل الترجمة ومع ظهور سطر ترجمة في اللعبة، راقب الإطار الأزرق في المعاينة بالهاتف ليكون محيطاً بالترجمة بالكامل.',
          'إذا احتجت تعديلاً ادخل "تحديد منطقة الترجمة"، واختر الحافة (أعلى، أسفل، يسار، يمين) وحرّك شريط التمرير.',
          'تحقق من حقل "النص المقروء داخل الإطار" للتأكد من التقاط الجملة كاملة بدقة.',
        ]),
        _Bullets([
          'إذا انقطع أول أو آخر الكلمات فوسّع الإطار.',
          'إذا اختفى السطر العلوي في الترجمات ذات السطرين فحرّك الحافة العلوية للأعلى.',
          'إذا التقط الإطار نصوصاً أخرى مثل أسماء المهام فصغّر الإطار وضعه بدقة على الترجمة.',
        ]),
        _Tip('تختلف مواضع الترجمة من لعبة لأخرى؛ راجع الإطار سريعاً عند بدء لعبة جديدة.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.textformat,
      color: Tokens.warning,
      title: 'الترجمة والمظهر',
      subtitle: 'المحرك والقاموس وشكل النص على التلفاز',
      children: [
        _Sub('محرك الترجمة'),
        _Keys([
          ('Google', 'يتطلب إنترنت ولا يحتاج مفتاح API. خيار مناسب لمعظم الألعاب.'),
          ('DeepL', 'صياغة أكثر طبيعية؛ يتطلب إدخال مفتاح API الخاص بك من DeepL.'),
          ('على الجهاز', 'يعمل بدون إنترنت بدقة أقل؛ يتم تحميل نموذج اللغة مرة واحدة عند أول استخدام.'),
        ]),
        _P('عند انقطاع الإنترنت تنتقل الترجمة تلقائياً إلى النموذج المحلي على الجهاز ثم تعود عند عودة الاتصال.'),
        _Sub('قاموس المصطلحات'),
        _P('لتثبيت ترجمة أسماء الشخصيات ومصطلحات الألعاب في الترجمة (الإنجليزية › العربية). '
            'يُفتح من الإعدادات › الترجمة › قاموس المصطلحات. العناصر داخل "terms" تُترجم بالصيغة التي تحددها، '
            'والأسماء داخل "keep" تبقى كما هي دون ترجمة.'),
        _Sub('المظهر على التلفاز'),
        _P('من الإعدادات › المظهر على التلفاز يمكنك تعديل حجم الخط ولونه وموضعه وتعتيم الخلفية وسُمك الخط، '
            'واختبار النتيجة فوراً عبر "إرسال ترجمة تجريبية للتلفاز".'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.wrench_fill,
      color: Tokens.danger,
      title: 'استكشاف الأخطاء وإصلاحها',
      subtitle: 'حلول المشاكل الشائعة',
      children: [
        _Sub('لم يتم العثور على PS5 أو فشل الاقتران'),
        _Bullets([
          'تأكد أن الهاتف وجهاز PS5 متصلان بنفس شبكة Wi-Fi (تجنّب شبكة الضيف أو عزل الأجهزة AP Isolation).',
          'تأكد أن "تمكين اللعب عن بُعد" مفعّل على حساب المستخدم الثاني في PS5.',
          'أدخل عنوان IP الخاص بـ PS5 يدوياً وتأكد من كتابة رمز الاقتران المكوّن من 8 أرقام بدقة.',
        ]),
        _Sub('الترجمة لا تظهر على التلفاز'),
        _Bullets([
          'تأكد أن تطبيق GameTranslator مفتوح على التلفاز وأن حالة التلفاز "متصل" على الهاتف.',
          'تأكد من ضبط "منطقة الترجمة" على مكان ظهور النص في اللعبة وأن حقل "النص المقروء داخل الإطار" يلتقط الكلام.',
          'جرّب زر "إرسال ترجمة تجريبية للتلفاز" للتحقق من وصول الرسائل للشاشة.',
        ]),
        _Sub('التلفاز عالق على عنوان قديم'),
        _P('إذا سبق ربط تطبيق التلفاز بحاسوب آخر فقد يبقى متصلاً به؛ مسح بيانات التطبيق على التلفاز مرة واحدة يعيد ضبطه للبحث عن الهاتف.'),
      ],
    ),
  ];
}

/// Reusable button inside the guide to open the TV installer wizard.
class InstallTvButton extends StatelessWidget {
  const InstallTvButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: GlowButton(
        icon: CupertinoIcons.tv_fill,
        label: 'تثبيت تطبيق التلفاز',
        onPressed: () => Navigator.of(context).push(appleRoute<void>((_) => const TvInstallPage())),
      ),
    );
  }
}

/// Help page opened from the home screen warning when TV stays disconnected.
class TvHelpPage extends StatelessWidget {
  const TvHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'مشكلة اتصال التلفاز',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          Glass(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _P('إذا كان تطبيق GameTranslator على التلفاز متصلاً بحاسوب سابقاً فقد يحاول الاتصال به بدلاً من الهاتف.'),
                _Steps([
                  'افتح إعدادات التلفاز › التطبيقات › GameTranslator.',
                  'اختر "مسح البيانات" أو "إيقاف إجباري" ثم أعد فتح التطبيق.',
                  'تأكد أن الهاتف والتلفاز على نفس شبكة Wi-Fi ثم ابدأ الترجمة من الهاتف.',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: Txt.headline.copyWith(color: Tokens.accentText)),
      );
}

class _P extends StatelessWidget {
  const _P(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Txt.subhead.copyWith(color: Tokens.textSecondary, height: 1.5)),
      );
}

class _Steps extends StatelessWidget {
  const _Steps(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Tokens.accentSoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: Txt.caption.copyWith(fontWeight: FontWeight.w700, color: Tokens.accentText)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(items[i], style: Txt.subhead.copyWith(height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7, left: 8),
                      child: Icon(CupertinoIcons.circle_fill, size: 6, color: Tokens.accentText),
                    ),
                    Expanded(child: Text(item, style: Txt.subhead.copyWith(height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Keys extends StatelessWidget {
  const _Keys(this.items);

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            for (final (key, desc) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(key, style: Txt.subhead.copyWith(fontWeight: FontWeight.w700, color: Tokens.textPrimary)),
                    ),
                    Expanded(child: Text(desc, style: Txt.subhead.copyWith(color: Tokens.textSecondary, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _Table extends StatelessWidget {
  const _Table(this.rows);

  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Tokens.inset,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Tokens.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(rows[i].$1, style: Txt.footnote.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(rows[i].$2, style: Txt.caption.copyWith(color: Tokens.textSecondary)),
                    ),
                    Icon(
                      rows[i].$3 ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: rows[i].$3 ? Tokens.success : Tokens.danger,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
