// SPDX-License-Identifier: AGPL-3.0-only
import 'package:material_ui/material_ui.dart';

import 'bridge.dart';
import 'main.dart';
import 'tv_install_page.dart';
import 'ui.dart';

/// Ayrıntılı kullanım rehberi: PS5 hazırlığından sorun gidermeye kadar her adım. iOS ayarlarındaki gibi bölüm
/// listesi ve her bölümün kendi sayfası. TV kurulum adımları docs/tv-kurulum.md ile aynıdır.
class GuideChapter {
  const GuideChapter({required this.icon, required this.color, required this.title, required this.subtitle, required this.children});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;
}

/// Rehber sekmesi: bölüm listesi.
class GuideTab extends StatelessWidget {
  const GuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitleList(
      title: 'دليل',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('كل شيء بدءًا من التثبيت وحتى استكشاف الأخطاء وإصلاحها، خطوة بخطوة.', style: Txt.body.copyWith(color: Tokens.textSecondary)),
        ),
        const GuideList(),
      ],
    );
  }
}

/// Bölümlerin gruplu listesi; satıra dokununca bölüm sayfası açılır.
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
        const GroupHeader('بداية'),
        Group(inset: 60, children: [for (var i = 0; i < 5; i++) cell(i)]),
        const GroupHeader('يستخدم'),
        Group(inset: 60, children: [for (var i = 5; i < 8; i++) cell(i)]),
        const GroupHeader('يساعد'),
        Group(inset: 60, children: [cell(8)]),
      ],
    );
  }
}

/// Tek bir bölümün sayfası. Kurulumdaki yardım düğmesi doğrudan ilgili bölümü açar.
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
      title: 'دليل',
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

/// Bölümlerin içeriği. [address]: telefonun ağ adresi (OBS adresini tam yazmak için); bilinmiyorsa genel yazılır.
List<GuideChapter> guideChapters(String? address) {
  final phone = address ?? 'عنوان الهاتف';
  return [
    const GuideChapter(
      icon: CupertinoIcons.arrow_right_arrow_left,
      color: Tokens.accent,
      title: 'كيف يعمل؟',
      subtitle: 'كل التخطيط في لمحة',
      children: [
        _P('يقوم GameTranslator بتوصيل ثلاثة أجهزة. تعمل اللعبة على PS5\'، وأنت تلعب على TV\'؛ يترجم الهاتف أحيانًا:'),
        _Steps([
          'يستقبل الهاتف صورة اللعبة من جهاز PS5\' عن طريق اللعب عن بعد. لا يتم استخدام الكاميرا.',
          'يقرأ المنطقة في الصورة التي يظهر فيها العنوان الفرعي ويترجم النص.',
          'يرسل الترجمة إلى TV\' على نفس شبكة Wi-Fi\'. يعرضه تطبيق GameTranslator على TV\' فوق اللعبة.',
        ]),
        _Sub('ما هو المطلوب؟'),
        _Bullets([
          'مستخدم ثانٍ على PS5 والإصدارات الأحدث (كما هو موضح أدناه).',
          'تلفزيون مثبت عليه تطبيق GameTranslator TV: LG أو Samsung أو Android TV / Google TV.',
          'شبكة منزلية واحدة (Wi-Fi) يتصل بها الهاتف وجهاز PS5 وTV\'.',
          'الإنترنت للترجمة عبر الإنترنت. هناك أيضًا خيار الترجمة الذي يعمل بدون الإنترنت.',
        ]),
        _Tip('يتم التثبيت مرة واحدة. ثم كل ما عليك فعله هو: بدء الترجمة وفتح التطبيق على TV\'.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.gamecontroller_fill,
      color: Tokens.indigo,
      title: 'تحضير PS5\'',
      subtitle: 'المستخدم الثاني واللعب عن بعد',
      children: [
        _Sub('1. أضف مستخدمًا ثانيًا'),
        _P('يتعامل جهاز PS5 مع الجهاز المتصل عبر ميزة اللعب عن بُعد على أنه وحدة التحكم الخاصة بهذا المستخدم. إذا كان الهاتف متصلاً بحسابك'
            'جهاز التحكم عن بعد الذي في يده ينفصل عن TV\'. ولهذا السبب يتصل الهاتف بمستخدم منفصل؛ تستمر في اللعب بحسابك الخاص.'),
        _Steps([
          'قم بإضافة مستخدم جديد على PS5\' (تغيير المستخدم › إضافة مستخدم من صورة الملف الشخصي على الشاشة الرئيسية).',
          'قم بتسجيل الدخول إلى هذا المستخدم باستخدام حساب PSN. إذا لم يكن لديك حساب، يمكنك فتح حساب مجانًا؛ لا حاجة إلى PS Plus.',
          'ستقوم أيضًا بتسجيل الدخول إلى PSN على الهاتف باستخدام هذا الحساب الثاني.',
        ]),
        _Sub('2. قم بتشغيل اللعب عن بعد'),
        _Steps([
          'قم بالتبديل إلى المستخدم الثاني على PS5\'.',
          'انتقل إلى الإعدادات > النظام > اللعب عن بعد \'.',
          'قم بتشغيل "تمكين اللعب عن بعد".',
        ]),
        _Sub('3. الاستيقاظ من وضع الراحة (اختياري)'),
        _P('بحيث عندما يبدأ جهاز PS5 في الترجمة أثناء وجوده في وضع السكون، يمكن للهاتف تنشيطه:'),
        _Steps([
          'انتقل إلى الإعدادات > النظام > توفير الطاقة > الميزات المتوفرة في وضع الراحة\'.',
          'قم بتشغيل "البقاء على اتصال بالإنترنت" و"تمكين تشغيل الشبكة على PS5\'".',
        ]),
        _Tip('إذا كنت لا ترغب في تنشيطه، فيمكنك إيقاف تشغيل الإعدادات › PS5 › "الاستيقاظ في وضع السكون" على الهاتف.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.link,
      color: Tokens.success,
      title: 'إقران الهاتف مع PS5',
      subtitle: 'تسجيل دخول PSN ورمز مكون من 8 أرقام',
      children: [
        _Sub('1. قم بتسجيل الدخول باستخدام PSN'),
        _Steps([
          'في شاشة الإعداد، انقر فوق "تسجيل الدخول باستخدام PSN". يتم فتح الصفحة الرئيسية الخاصة بـ Sony\'.',
          'قم بتسجيل الدخول بحساب المستخدم الثاني على PS5\'.',
          'عند اكتمال تسجيل الدخول، يعود التطبيق تلقائيًا إلى التثبيت ويعرض رسالة "حساب PSN متصل".',
        ]),
        _Tip('تنتقل كلمة المرور الخاصة بك مباشرةً إلى Sony\'؛ يقوم التطبيق بتخزين رقم الهوية الخاص بحسابك فقط.'),
        _Sub('2. أدخل رمز الاقتران'),
        _Steps([
          'بينما أنت المستخدم الثاني على PS5\'، انتقل إلى الإعدادات › النظام › اللعب عن بعد › "إقران الجهاز".',
          'يظهر رمز مكون من 8 أرقام وعد تنازلي على الشاشة. الرمز صالح لمدة 5 دقائق تقريبًا.',
          'حدد PS5\' من قائمة "تم العثور على وحدة التحكم" على الهاتف.',
          'اكتب الرمز في المربعات وانقر على "إقران".',
        ]),
        _Sub('إذا لم يكن PS5 مدرجًا في القائمة'),
        _Bullets([
          'تحقق مما إذا كان الهاتف وجهاز PS5 متصلين بشبكة Wi-Fi نفسها؛ يجب ألا تكون هناك شبكة ضيف أو بيانات جوال.',
          'اضغط على "تحديث".',
          'إذا ظل الأمر لا يعمل، فانقر على "اكتب عنوان IP يدويًا". العنوان مكتوب في PS5\' في الإعدادات › الشبكة › حالة الاتصال › عرض حالة الاتصال \'.',
        ]),
        _Tip('يتم الاقتران مرة واحدة. إذا تغير عنوان PS5\'، فسيجده التطبيق على الشبكة مرة أخرى.'),
      ],
    ),
    GuideChapter(
      icon: CupertinoIcons.tv_fill,
      color: Tokens.purple,
      title: 'إعداد TV\'',
      subtitle: 'دعم TV\'s وتطبيق التلفزيون',
      children: [
        const _P('يوجد تطبيق GameTranslator TV منفصل يعرض الترجمات على TV\'. نظرًا لعدم توفره في المتاجر بعد، انتقل إلى TV\''
            'بمجرد تثبيتها. يمكنك تثبيته على LG وAndroid TV\' من هذا الهاتف؛ يتم التثبيت على Samsung\' حاليًا من الكمبيوتر.'),
        const InstallTvButton(),
        const _Sub('ما هي أجهزة TV\' المدعومة؟'),
        const _Table([
          ('إل جي', 'ويب أو إس 4 وما فوق', true),
          ('سامسونج', 'تايزن، 2019 وما بعده', true),
          ('أندرويد تي في/جوجل تي في', 'فيستل، أرتشيليك، بيكو، جروندج، فيليبس، سوني، تي سي إل وغيرها', true),
          ('آحرون', 'نماذج Linux من Vestel/Arçelik/Beko/Grundig\'، Philips Saphi، Titan OS', false),
        ]),
        const _Tip('TV\'n أندرويد؟ إذا كان مكتوبًا Google Play Store أو "Google TV" على الشاشة الرئيسية، فهو Android\'.'),
        const _Sub('إل جي'),
        const _Steps([
          'افتح حساب مطور LG مجانيًا على webostv.developer.lge.com من جهاز الكمبيوتر الخاص بك.',
          'قم بتثبيت تطبيق "وضع المطور" من LG Content Store\' على TV\'، وقم بتسجيل الدخول باستخدام حسابك وتشغيل "حالة وضع المطور". يبدأ التلفاز من جديد.',
          'افتح "Key Server" في تطبيق وضع المطور على TV\'.',
          'في معالج "تثبيت تطبيق TV" على الهاتف، حدد LG\'، وابحث عن TV\' واكتب كلمة المرور المكونة من 6 أحرف على الشاشة'
              '(الخطوة التلفزيونية لـ GameTranslator\' على الكمبيوتر تفعل الشيء نفسه).',
        ]),
        const _P('على LG\'، يظل وضع المطور قيد التشغيل لمدة أقصاها 1000 ساعة. إذا كنت لن تستخدمه لفترة طويلة، فانتقل إلى وضع المطور قبل انتهاء صلاحيته.'
            'اضغط على "تمديد" في التطبيق؛ إذا انتهى الوقت، فسيتم حذف تطبيق التلفزيون وسيتعين عليك تثبيته من البداية.'),
        const _Sub('سامسونج'),
        const _Steps([
          'افتح شاشة التطبيقات على TV\' واضغط 1 2 3 4 5 على جهاز التحكم عن بعد. يتم فتح نافذة وضع المطور.',
          'افتح "وضع المطور" واكتب عنوان جهاز الكمبيوتر الخاص بك في حقل "Host PC IP".',
          'قم بإيقاف تشغيل TV\' بالكامل وتشغيله عن طريق الضغط باستمرار على زر الطاقة.',
          'حدد TV\' في الخطوة التلفزيونية الخاصة بـ GameTranslator\' على الكمبيوتر. في الصفحة التي تفتح، قم بتسجيل الدخول باستخدام حساب Samsung مجاني؛ تم توقيع التطبيق وتثبيته.',
        ]),
        const _Sub('أندرويد تي في/جوجل تي في'),
        const _Steps([
          'في TV\'، انتقل إلى الإعدادات › تفضيلات الجهاز › About\' (في Google TV\'، انتقل إلى الإعدادات › النظام › حول).',
          'فوق "رقم الإصدار"، اضغط على "موافق" 7 مرات.',
          'قم بتشغيل "تصحيح أخطاء USB" (أيضًا "تصحيح أخطاء الشبكة" إذا كان متاحًا) في خيارات المطور\'.',
          'في معالج "تثبيت تطبيق TV" على الهاتف، حدد "Android TV / Google TV" وقم بتأكيد سؤال الإذن في TV\'.',
        ]),
        const _P('إذا كان التلفزيون لا يسمح بتصحيح أخطاء الشبكة، فيمكنك أيضًا تثبيته باستخدام محرك أقراص USB: من صفحة إصدارات GameTranslator\''
            'قم بتنزيل ملف APK الخاص بتطبيق التلفزيون، وانسخه إلى الذاكرة وافتحه باستخدام مدير الملفات في TV\' وقم بتثبيته.'),
        const _Sub('بعد التثبيت'),
        const _P('يجد تطبيق التلفزيون الهاتف على الشبكة نفسها؛ لا تحتاج إلى كتابة عنوان TV\' في هاتفك. Samsung\' إلى الكمبيوتر'
            'مطلوب فقط للتثبيت. ومن الممكن أن تظل مغلقة بعد ذلك.'),
        const _Sub('للمذيعين: OBS'),
        _P('عند تشغيل الترجمة، يتم عرض الترجمات أيضًا كصفحة ويب. أضف "مصدر المتصفح" إلى OBS\' واستخدمه كعنوان.'
            'http://$phone:8787/obs yaz (1920×1080). Sayfanın zemini saydamdır; TV\'nin tarayıcısında oyunun üstünde göstermez, '
            'لتخطيطات البث والتسجيل فقط.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.play_fill,
      color: Tokens.accent,
      title: 'الاستخدام الأول',
      subtitle: 'ابدأ الترجمة وشاهدها على TV\'',
      children: [
        _Steps([
          'افتح اللعبة على PS5\' بحسابك الخاص وقم بتشغيل الترجمة في إعدادات اللعبة.',
          'على الهاتف، اضغط على الزر الكبير الموجود على الشاشة الرئيسية. سيُطلب منك إذن الإخطار في المرة الأولى؛ دع الترجمة تستمر في الخلفية.',
          'عندما تكون الحالة "تشغيل الترجمة"، ستظهر رسالة "متصل" على بطاقة PS5. يستغرق الاتصال الأولي بضع ثوانٍ.',
          'افتح GameTranslator على TV\'. في غضون ثوانٍ قليلة، ستكون بطاقة التلفزيون الموجودة على الهاتف "متصلة".',
          'إذا لم تظهر صورة اللعبة على TV\'، فافتح اللوحة باستخدام الزر "موافق" وحدد إدخال HDMI الذي يتصل به PS5\' بالزرين الأيسر والأيمن.',
          'اضغط على "إرسال ترجمات اختبارية إلى TV\'" على الهاتف. إذا رأيت النص على TV\'، فكل شيء جاهز.',
        ]),
        _Tip('يمكنك إيقاف تشغيل شاشة هاتفك أثناء تشغيل الترجمة. للتوقف، اضغط على الزر الموجود في التطبيق أو "إيقاف" في الإشعار.'),
        _Sub('الرحلات القادمة'),
        _P('خطوتين فقط: ابدأ الترجمة على الهاتف، وافتح GameTranslator\'on TV\'.'),
        _Sub('البطارية والتدفئة'),
        _P('يقوم الهاتف باستمرار بفك تشفير الفيديو وقراءة النص؛ استخدامه على تهمة لجلسات طويلة.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.dot_radiowaves_left_right,
      color: Tokens.gray,
      title: 'جهاز التحكم عن بعد للتلفزيون',
      subtitle: 'المفاتيح في تطبيق التلفزيون',
      children: [
        _P('عندما يكون GameTranslator مفتوحًا على TV\'، تقوم أزرار جهاز التحكم عن بعد بما يلي:'),
        _Keys([
          ('نعم', 'يفتح ويغلق لوحة الحالة (إدخال HDMI، حالة الاتصال).'),
          ('يسار / يمين', 'يقوم بتبديل دخل HDMI عندما تكون اللوحة مفتوحة.'),
          ('1 – 4', 'يحدد إدخال HDMI مباشرة.'),
          ('أعلى/أسفل', 'لتحريك الترجمة لأعلى أو لأسفل على الشاشة.'),
          ('أحمر', 'يعرض مقال TV\' الخاص.'),
          ('أخضر', 'فتح وإغلاق لوحة الحالة.'),
          ('أزرق', 'يبدأ العرض التوضيحي أو يوقفه باستخدام عينة من الترجمة.'),
          ('خلف', 'قم بإنهاء التطبيق.'),
        ]),
        _Tip('تلعب اللعبة باستخدام وحدة تحكم PS5؛ جهاز التحكم عن بعد الخاص بالتلفزيون مطلوب لهذه الإعدادات فقط.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.crop,
      color: Tokens.teal,
      title: 'تعيين منطقة الترجمة',
      subtitle: 'أين تنظر على شاشة الهاتف',
      children: [
        _P('لا يقرأ الهاتف الشاشة بأكملها، بل يقرأ فقط المنطقة التي تظهر فيها الترجمة. إذا كانت المنطقة في المكان الخطأ، فلن يكون هناك ترجمة أو'
            'تتم ترجمة النصوص الأخرى التي تظهر على الشاشة.'),
        _Steps([
          'مع تشغيل الترجمة، انتظر حتى تظهر الترجمة في اللعبة.',
          'ابحث عن الإطار الأزرق في المعاينة على الشاشة الرئيسية: يجب أن يكون العنوان الفرعي بأكمله داخل الإطار.',
          'إذا لم يكن الأمر كذلك، فانقر على "تعيين منطقة الترجمة". حدد الحافة العلوية أو السفلية أو اليسرى أو اليمنى وحركها باستخدام شريط التمرير.',
          'يعرض سطر "القراءة في الإطار" الموجود على الشاشة الرئيسية ما يقرأه الهاتف حاليًا؛ يجب أن يظهر العنوان الفرعي بأكمله هناك.',
        ]),
        _Bullets([
          'إذا تم قطع بداية الجملة أو نهايتها، قم بتوسيع الإطار.',
          'إذا اختفى السطر العلوي في ترجمات مكونة من سطرين، فحرك الحافة العلوية لأعلى.',
          'في حالة ترجمة نصوص أخرى مثل نصوص المهمة وأسماء الخرائط، قم بتضييق الإطار.',
        ]),
        _Tip('تضع كل لعبة الترجمات في مكان مختلف؛ عندما تبدأ لعبة جديدة، تكفيك نظرة واحدة على المنطقة.'),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.textformat,
      color: Tokens.warning,
      title: 'الترجمة والمظهر',
      subtitle: 'المحرك والقاموس والنص في TV\'',
      children: [
        _Sub('محرك الترجمة'),
        _Keys([
          ('جوجل', 'يتطلب الإنترنت، لا يوجد مفتاح مطلوب. أفضل بداية لمعظم الألعاب.'),
          ('ديب إل', 'يصنع جملاً أكثر طبيعية. تحتاج إلى كتابة مفتاح API الخاص بك الذي حصلت عليه من DeepL\'.'),
          ('على الجهاز', 'يعمل بدون انترنت؛ جودتها أقل من غيرها. عند أول استخدام، ينزل نموذج اللغة مرة واحدة.'),
        ]),
        _P('في حالة انقطاع الإنترنت، تتحول الترجمة تلقائيًا إلى النموذج الموجود على الجهاز وتعود عند استعادة الاتصال.'),
        _Sub('معجم المصطلحات'),
        _P('لإصلاح أسماء الشخصيات ومصطلحات اللعبة التي أفسدتها الترجمة (الإنجليزية → التركية فقط).'
            'يتم فتحه من الإعدادات › الترجمة › المسرد\'. المصطلحات الموجودة في "المصطلحات" مترجمة إلى اللغة التركية التي كتبتها،'
            'تظل الأسماء في "الاحتفاظ" كما هي.'),
        _Sub('الظهور على شاشة التلفزيون\''),
        _Bullets([
          'حجم الخط ولونه: الإعدادات › المظهر على TV\'.',
          'موقع الترجمة: ثابت في أعلى الشاشة أو أسفلها أو أسفلها، بحيث يغطي الترجمة الخاصة باللعبة.',
          'ظلام الخلفية: ظلام الصندوق الأسود خلف النص. إذا كنت تقوم بتغطية ترجمات اللعبة، فاجعلها عالية.',
        ]),
      ],
    ),
    const GuideChapter(
      icon: CupertinoIcons.wrench_fill,
      color: Tokens.danger,
      title: 'استكشاف الأخطاء وإصلاحها',
      subtitle: 'المواقف الشائعة',
      children: [
        _Qa('الترجمة لا تبدأ، تبقى عند "الاتصال بـ PS5\'"', [
          'هل تم تشغيل PS5؟ إذا كان في وضع السكون، فقم بتشغيل إعدادات التنبيه كما في قسم "تحضير PS5\'".',
          'هل الهاتف متصل بشبكة Wi-Fi\' وعلى نفس الشبكة مثل جهاز PS5؟',
          'هل تم تمكين اللعب عن بعد على PS5\'؟',
        ]),
        _Qa('""اللعب عن بعد قيد الاستخدام بواسطة جهاز آخر""', [
          'يقبل PS5 اتصالاً واحدًا للعب عن بُعد في كل مرة. إذا كان GameTranslator أو تطبيق Remote Play آخر مفتوحًا على الكمبيوتر، فأغلقه.',
          'إذا أوقفته للتو، انتظر بضع ثوانٍ؛ سيحاول التطبيق مرة أخرى تلقائيًا.',
        ]),
        _Qa('جهاز التحكم عن بعد انقطع عن TV\'', [
          'الهاتف مرتبط بالحساب الذي تلعب به. قم بالتبديل إلى حساب المستخدم الثاني عبر الإعدادات › PS5 › "تغيير حساب PSN".',
        ]),
        _Qa('تبقى بطاقة البث التلفزيوني على وضع "الانتظار"', [
        'هل تطبيق GameTranslator مفتوح على TV\'؟',
        'هل التلفاز على نفس شبكة الهاتف؟ لا ينبغي أن تكون شبكة ضيف أو مودم مختلف.',
        'إذا كان GameTranslator مفتوحًا على الكمبيوتر، فأغلقه؛ يتصل التلفزيون بأول جهاز يجده على الشبكة.',
        'إذا كان تطبيق التلفزيون متصلاً بالكمبيوتر من قبل، فقد يكون عالقًا في هذا العنوان. اتبع خطوات "إذا لم يتمكن التلفزيون من العثور على الهاتف" أدناه.',
      ]),
      _Sub('إذا لم يتمكن التلفزيون من العثور على الهاتف'),
      ...tvRecoverySteps,
      _Qa('لا توجد صورة للعبة على TV\'، الشاشة سوداء', [
          'افتح اللوحة باستخدام OK وحدد إدخال HDMI الذي يتصل به PS5\' باستخدام اليسار/اليمين.',
          'لا تقوم بعض أجهزة Android TV\'s بإخراج صورة HDMI إلى تطبيق آخر؛ o تحتوي قنوات TV\'s على ترجمات لكن الخلفية تظل سوداء.',
        ]),
        _Qa('ترجمات لا تأتي أبدا', [
          'هل تم تشغيل الترجمة الخاصة باللعبة؟',
          'إذا كانت عبارة "القراءة في الإطار" على الشاشة الرئيسية فارغة، فهذا يعني أن المنطقة في المكان الخطأ؛ راجع قسم "تعيين منطقة الترجمة".',
          'هل لغة اللعبة هي نفس اللغة المصدر في الإعدادات › Translation\'؟',
          'إذا نجح "إرسال عنوان فرعي اختباري إلى TV\'"، يكون اتصال التلفزيون مستقرًا؛ المشكلة في القراءة .',
        ]),
        _Qa('الترجمة غير كاملة أو لا معنى لها', [
          'إذا كانت بداية الجملة أو نهايتها مفقودة، قم بتوسيع المنطقة.',
          'إذا كان المحرك "على الجهاز"، فانتقل إلى Google أو DeepL\'.',
          'الخطوط الفاخرة جدًا أو الصغيرة جدًا تجعل القراءة صعبة؛ يساعد على زيادة حجم الترجمة وإضافة الخلفية في اللعبة.',
        ]),
        _Qa('الترجمة تأتي متأخرة', [
          'إذا أمكن، أبقِ الهاتف وجهاز PS5 بالقرب من المودم؛ يؤدي ضعف شبكة Wi-Fi إلى تأخير الصورة.',
          'تؤثر سرعة الإنترنت أيضًا على محركات الإنترنت.',
        ]),
        _Qa('تتوقف الترجمة عند إيقاف تشغيل الشاشة', [
          'قد يكون موفر طاقة بطارية هاتفك هو الذي يوقف التطبيق. حدد "غير مقيد" من إعدادات هاتفك > التطبيقات > GameTranslator > قسم البطارية.',
          'إذا قمت بإيقاف تشغيل إذن الإشعارات، فقم بتشغيله؛ تعمل خدمة الخلفية مع الإخطار.',
        ]),
        _Tip('إذا كانت هناك مشكلة لا يمكنك حلها، فيمكنك نسخ السجلات ومشاركتها في الإعدادات › حول › Log\'.'),
      ],
    ),
  ];
}

/// Paragraf.
class _P extends StatelessWidget {
  const _P(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: const TextStyle(color: Tokens.textSecondary, fontSize: 15.5, height: 1.45, letterSpacing: -0.2)),
      );
}

/// Bölüm içi ara başlık.
class _Sub extends StatelessWidget {
  const _Sub(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Text(text, style: Txt.headline),
      );
}

/// Numaralı adımlar.
class _Steps extends StatelessWidget {
  const _Steps(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Tokens.accentSoft, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(color: Tokens.accentText, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(items[i], style: const TextStyle(fontSize: 15.5, height: 1.42, letterSpacing: -0.2)),
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

/// Sırasız liste.
class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 9, right: 12),
                    child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Tokens.accentText, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(item, style: const TextStyle(color: Tokens.textSecondary, fontSize: 15.5, height: 1.42, letterSpacing: -0.2))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// İpucu kutusu.
class _Tip extends StatelessWidget {
  const _Tip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Notice(icon: CupertinoIcons.lightbulb_fill, text: text),
      );
}

/// Ad ve açıklama çiftleri: kumanda tuşları, çeviri motorları.
class _Keys extends StatelessWidget {
  const _Keys(this.items);

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (final (name, text) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 104,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Tokens.inset,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Tokens.border),
                    ),
                    child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(text, style: const TextStyle(color: Tokens.textSecondary, fontSize: 14, height: 1.4)),
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

/// Desteklenen TV'ler: marka, ayrıntı ve destek durumu.
class _Table extends StatelessWidget {
  const _Table(this.rows);

  final List<(String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(color: Tokens.inset, borderRadius: BorderRadius.circular(16), border: Border.all(color: Tokens.border, width: 0.8)),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      rows[i].$3 ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                      size: 20,
                      color: rows[i].$3 ? Tokens.success : Tokens.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(rows[i].$2, style: const TextStyle(color: Tokens.textSecondary, fontSize: 13.5, height: 1.35)),
                          if (!rows[i].$3)
                            const Text('غير مدعوم: لا يمكن تثبيت التطبيقات على أجهزة TV\'s هذه.', style: TextStyle(color: Tokens.danger, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sorun ve denenecekler.
class _Qa extends StatelessWidget {
  const _Qa(this.question, this.answers);

  final String question;
  final List<String> answers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(CupertinoIcons.question_circle_fill, size: 18, color: Tokens.warning),
              ),
              Expanded(child: Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35))),
            ],
          ),
          _Bullets(answers),
        ],
      ),
    );
  }
}

/// TV uygulaması eski bir adrese (ör. kapalı bilgisayara) takılı kaldığında yapılacaklar. Sorun gidermede ve
/// ana ekrandaki uyarıdan açılan sayfada aynı metin kullanılır.
const tvRecoverySteps = <Widget>[
  _P('يتذكر تطبيق التلفزيون العنوان الذي تم الاتصال به آخر مرة. إذا تم توصيله بالكمبيوتر من قبل، بدلاً من الاتصال بالهاتف'
      'يمكن الاستمرار في محاولة العنوان. عند حذف العنوان المسجل، يقوم التطبيق بمسح الشبكة مرة أخرى والعثور على الهاتف.'),
  _Sub('Android TV / Google TV (TCL، Sony، Philips، Vestel...)'),
  _Steps([
    'على TV\'، انتقل إلى الإعدادات › Applications\' وحدد GameTranslator\' من القائمة (قد يكون عرض جميع التطبيقات" مطلوبًا).',
    'حدد "مسح البيانات" وأكد. لا يتم حذف التطبيق، تتم إعادة تعيين العنوان المسجل والإعدادات فقط.',
    'أثناء فتح الترجمة على الهاتف، أعد فتح GameTranslator\' على TV\'.',
    'انتظر لمدة دقيقة. يصبح مربع التلفزيون الموجود على الهاتف "متصلاً".',
  ]),
  _Sub('سامسونج و إل جي'),
  _Steps([
    'لا يمكن حذف بيانات التطبيق بشكل منفصل على TV\'s: قم بإزالة GameTranslator\' من TV\'.',
    'أعد التثبيت باستخدام GameTranslator على الكمبيوتر (الخطوات في قسم "تحضير TV\'").',
    'أغلق GameTranslator\' على الكمبيوتر، وابدأ الترجمة على الهاتف، وافتح التطبيق على TV\'.',
  ]),
  _Sub('إن لم يكن مرة أخرى'),
  _Bullets([
    'هل تم إيقاف تشغيل GameTranslator على الكمبيوتر؟ إذا كان قيد التشغيل، يتصل التلفزيون به.',
    'هل الهاتف والتلفزيون على نفس شبكة Wi-Fi؟ إذا تم تشغيل "عزل العميل" (عزل AP) في المودم، فلن تتمكن الأجهزة من رؤية بعضها البعض.',
    'نظرًا لإعادة ضبط إعداد HDMI على TV\' أيضًا، افتح اللوحة باستخدام "موافق" وحدد إدخال PS5\' مرة أخرى.',
  ]),
];

/// Ana ekrandaki "التلفزيون لا يزال غير متصل" uyarısından açılan yardım sayfası.
class TvHelpPage extends StatelessWidget {
  const TvHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'التلفزيون غير متصل',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          Glass(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: tvRecoverySteps),
          ),
        ],
      ),
    );
  }
}

/// Rehberdeki "تثبيت تطبيق التلفزيون" düğmesi: telefondan kurulum sihirbazını açar.
class InstallTvButton extends StatelessWidget {
  const InstallTvButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: GlowButton(
          icon: CupertinoIcons.tv_fill,
          label: 'تثبيت تطبيق التلفزيون',
          onPressed: () => Navigator.of(context).push(appleRoute<void>((_) => const TvInstallPage())),
        ),
      );
}
