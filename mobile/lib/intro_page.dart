// SPDX-License-Identifier: AGPL-3.0-only
import 'package:material_ui/material_ui.dart';

import 'main.dart';
import 'ui.dart';

/// التعريف الأولي عند التشغيل: ماذا يفعل التطبيق، كيف يعمل، وما المطلوب قبل البدء.
/// يمكن فتحه مجدداً من الإعدادات › حول؛ وعندها يقوم [onDone] بإغلاق الصفحة فقط.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key, required this.onDone, this.replay = false});

  final Future<void> Function() onDone;

  /// إذا أُعيد فتحه بعد اكتمال الإعداد، يرجع الزر الأخير للخلف بدلاً من الإعداد.
  final bool replay;

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  static const pageCount = 3;

  final controller = PageController();
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void next() {
    if (page == pageCount - 1) {
      widget.onDone();
    } else {
      controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = page == pageCount - 1;
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last ? null : () => widget.onDone(),
                    child: Text(
                      widget.replay ? 'إغلاق' : 'تخطي',
                      style: const TextStyle(color: Tokens.textSecondary, fontSize: 17, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (index) => setState(() => page = index),
                children: const [_WelcomePage(), _HowPage(), _NeedsPage()],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: i == page ? 11 : 9,
                    height: i == page ? 11 : 9,
                    decoration: BoxDecoration(
                      color: i == page ? Tokens.accentText : Tokens.border,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: GlowButton(
                onPressed: next,
                label: last ? (widget.replay ? 'تم' : 'ابدأ الإعداد') : 'التالي',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// هيكل كل صفحة تعريفية: صورة/عنصر بالأعلى، وعنوان ووصف بالأسفل.
class _IntroLayout extends StatelessWidget {
  const _IntroLayout({required this.visual, required this.title, required this.body, this.extra});

  final Widget visual;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              visual,
              const SizedBox(height: 34),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Txt.largeTitle,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Txt.body.copyWith(color: Tokens.textSecondary),
              ),
              if (extra != null) ...[const SizedBox(height: 24), extra!],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return _IntroLayout(
      visual: Column(
        children: [
          const GtLogo(size: 104),
          const SizedBox(height: 14),
          const Text('GameTranslator', style: Txt.title2),
          const SizedBox(height: 28),
          const _SceneCard(),
        ],
      ),
      title: 'العب بلغتك',
      body: 'يترجم ترجمات ألعاب PS5 فوراً إلى العربية ويعرضها على التلفاز.',
    );
  }
}

/// مشهد لعبة تجريبي: الترجمة الأصلية وفوقها الترجمة العربية كما ستظهر على التلفاز.
class _SceneCard extends StatelessWidget {
  const _SceneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Tokens.accentText.withValues(alpha: 0.55), width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/intro_scene.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(-0.5, 0),
                filterQuality: FilterQuality.medium,
              ),
              // تعتيم أسفل المشهد لوضوح الترجمة.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  children: [
                    Glass(
                      blur: true,
                      radius: 999,
                      tint: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: const Text(
                        'We have to leave before sunrise.',
                        style: TextStyle(color: Color(0xFFD5D9E0), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xE60B0D12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x59FFFFFF), width: 0.8),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'يجب أن نغادر قبل شروق الشمس.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
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

class _HowPage extends StatelessWidget {
  const _HowPage();

  @override
  Widget build(BuildContext context) {
    return const _IntroLayout(
      visual: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: FlowRow(
          nodes: [
            FlowNode(icon: CupertinoIcons.gamecontroller_fill, label: 'PS5', detail: 'الصورة', color: Tokens.textSecondary),
            FlowNode(icon: CupertinoIcons.device_phone_portrait, label: 'الجوال', detail: 'يترجم', color: Tokens.accent),
            FlowNode(icon: CupertinoIcons.tv_fill, label: 'التلفاز', detail: 'يعرض', color: Tokens.success),
          ],
        ),
      ),
      title: 'جوالك هو المترجم الوسيط',
      body: 'يلتقط الجوال صورة اللعبة من PS5 عبر Remote Play، ويقرأ الترجمة ويترجمها ويرسلها للتلفاز. '
          'بدون كاميرا، ويستمر بالعمل حتى لو أطفأت الشاشة.',
    );
  }
}

class _NeedsPage extends StatelessWidget {
  const _NeedsPage();

  @override
  Widget build(BuildContext context) {
    return const _IntroLayout(
      visual: SizedBox.shrink(),
      title: 'قبل أن تبدأ',
      body: 'يستغرق الإعداد بضع دقائق. جهّز التالي:',
      extra: Column(
        children: [
          _Need(
            icon: CupertinoIcons.person_2_fill,
            title: 'مستخدم ثانٍ على PS5',
            text: 'العب بحسابك الأساسي، ويرتبط الجوال بحساب ثانٍ حتى لا ينفصل يد التحكم عن التلفاز.',
          ),
          _Need(
            icon: CupertinoIcons.tv_fill,
            title: 'تطبيق GameTranslator على التلفاز',
            text: 'يعمل على Samsung وLG وAndroid TV، ويُثبّت عبر GameTranslator على الكمبيوتر.',
          ),
          _Need(
            icon: CupertinoIcons.wifi,
            title: 'نفس شبكة Wi-Fi',
            text: 'يجب أن يكون الجوال وPS5 والتلفاز على نفس الشبكة المنزلية.',
          ),
        ],
      ),
    );
  }
}

class _Need extends StatelessWidget {
  const _Need({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: Tokens.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Tokens.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: Tokens.accentText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(color: Tokens.textSecondary, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
