// SPDX-License-Identifier: AGPL-3.0-only
import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoActionSheet,
        CupertinoActionSheetAction,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoIcons,
        CupertinoPageRoute,
        showCupertinoDialog,
        showCupertinoModalPopup;
import 'package:material_ui/material_ui.dart';

import 'main.dart';

export 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoActivityIndicator, CupertinoIcons, CupertinoSlider, CupertinoSlidingSegmentedControl, CupertinoSwitch;
export 'flow.dart';

/// Shared glass UI primitives: translucent surfaces, grouped lists, headers, buttons, and sheets.
// ---------------------------------------------------------------------------------------------- Background & glass
/// Ambient dark background with soft radial color blobs behind translucent glass surfaces.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _BackgroundPainter(), size: Size.infinite));
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(area, Paint()..color = Tokens.background);
    void blob(double x, double y, double radius, Color color) {
      final center = Offset(size.width * x, size.height * y);
      final r = size.width * radius;
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    blob(0.00, 0.22, 1.00, const Color(0x660A84FF)); // blue top-left
    blob(1.05, 0.50, 0.90, const Color(0x4D5E5CE6)); // indigo right-mid
    blob(0.25, 1.00, 0.95, const Color(0x4032ADE6)); // cyan bottom-left
    blob(0.95, 0.05, 0.60, const Color(0x33BF5AF2)); // purple top-right
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}

/// Translucent glass surface with optional tint and backdrop blur.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = 26, this.padding, this.tint, this.blur = false, this.clip = false});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool blur;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final color = tint;
    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: color == null
            ? Tokens.glassFill
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.40), color.withValues(alpha: 0.18)],
              ),
        border: Border.all(color: color == null ? Tokens.border : color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: clip ? ClipRRect(borderRadius: BorderRadius.circular(radius - 1), child: child) : child,
    );
    if (blur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: surface),
      );
    }
    return surface;
  }
}

// ---------------------------------------------------------------------------------------------- Page scaffolds
/// Sub-page scaffold with a back button in a circular glass badge and centered title.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({super.key, this.appBar, required this.body, this.title, this.actions});

  /// Custom app bar; if omitted and [title] is set, a default navigation bar is built.
  final PreferredSizeWidget? appBar;
  final String? title;
  final List<Widget>? actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final bar = appBar ?? (title == null ? null : navBar(context, title!, actions: actions));
    return Stack(
      fit: StackFit.expand,
      children: [
        const GlassBackground(),
        Scaffold(backgroundColor: Colors.transparent, appBar: bar, body: bar == null ? body : SafeArea(top: false, child: body)),
      ],
    );
  }

  static PreferredSizeWidget navBar(BuildContext context, String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) {
    return AppBar(
      toolbarHeight: 52,
      leadingWidth: 64,
      automaticallyImplyLeading: false,
      leading: Navigator.of(context).canPop() ? const Center(child: GlassBackButton()) : null,
      title: Text(title),
      actions: actions == null ? null : [...actions, const SizedBox(width: 8)],
      bottom: bottom,
    );
  }
}

class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key});

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        tooltip: 'رجوع',
        onTap: () => Navigator.of(context).maybePop(),
      );
}

/// Circular glass icon button for navigation bars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.size = 40});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Tokens.surface,
        shape: const CircleBorder(side: BorderSide(color: Tokens.border, width: 0.8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.5, color: Tokens.textPrimary)),
        ),
      ),
    );
  }
}

/// Tab page with large title and bottom clearance above the floating tab bar.
class LargeTitleList extends StatelessWidget {
  const LargeTitleList({super.key, required this.title, required this.children, this.trailing, this.bottomSpace = 118});

  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, bottomSpace),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 14),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: Txt.largeTitle)),
                  ?trailing,
                ],
              ),
            ),
            ...children,
          ],
        ),
        // Top status-bar blur strip so scrolling text does not clash with status icons.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating glass tab bar positioned above the bottom safe area.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.items, required this.index, required this.onTap});

  final List<(IconData, IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x40FFFFFF), Color(0x1FFFFFFF)],
            ),
            border: Border.all(color: const Color(0x40FFFFFF), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 96,
                    decoration: BoxDecoration(
                      color: i == index ? const Color(0x38FFFFFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(i == index ? items[i].$2 : items[i].$1, size: 24, color: i == index ? Tokens.accent : Tokens.textPrimary),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: i == index ? Tokens.accent : Tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------- Grouped lists
/// Section header label above grouped settings/cards.
class GroupHeader extends StatelessWidget {
  const GroupHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
        child: Text(text, style: Txt.footnote.copyWith(color: Tokens.textSecondary, fontWeight: FontWeight.w500)),
      );
}

/// Explanatory footer text below a group.
class GroupFooter extends StatelessWidget {
  const GroupFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: Text(text, style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
      );
}

/// Inset grouped glass container with thin dividers between rows.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.inset = 16});

  final List<Widget> children;

  /// Left/start divider indent aligned with row text.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Glass(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Padding(padding: EdgeInsets.only(left: inset), child: const Divider()),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Rounded square icon badge used in list rows.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, this.color, {super.key, this.size = 30});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.24)),
      child: Icon(icon, size: size * 0.6, color: Colors.white),
    );
  }
}

/// List row supporting leading icon, title, subtitle, value, trailing widget, checkmark, or chevron.
class Cell extends StatelessWidget {
  const Cell({
    super.key,
    this.icon,
    this.iconColor = Tokens.accent,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.checked,
    this.titleColor,
  });

  final IconData? icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  /// Muted label shown on the trailing side.
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  /// When non-null in selection lists, shows a blue checkmark if true.
  final bool? checked;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final hasLeading = icon != null;
    final hasTrailing = trailing != null || checked == true || value != null || chevron;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hasLeading ? 14 : 16, subtitle == null ? 13 : 11, hasTrailing ? 12 : 16, subtitle == null ? 13 : 11),
          child: Row(
            children: [
              if (hasLeading) ...[
                IconTile(icon!, iconColor),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Txt.body.copyWith(color: titleColor ?? Tokens.textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Txt.footnote.copyWith(color: Tokens.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!, style: Txt.body.copyWith(color: Tokens.textSecondary)),
              ],
              if (checked == true) ...[
                const SizedBox(width: 8),
                const Icon(CupertinoIcons.checkmark, size: 18, color: Tokens.accent),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_forward, size: 16, color: Color(0x66EBEBF5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------- Buttons & badges
/// Primary capsule action button.
class GlowButton extends StatelessWidget {
  const GlowButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else if (icon != null)
              Icon(icon, size: 20),
            if (busy || icon != null) const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Tinted callout card for tips, warnings, or errors.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.icon, required this.text, this.title, this.color = Tokens.accent, this.action, this.compact = false});

  final IconData icon;
  final String? title;
  final String text;
  final Color color;
  final Widget? action;

  /// Compact padding and color for single-line status notices.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: compact ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: color.withValues(alpha: compact ? 0.35 : 0.30), width: 0.9),
      ),
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Row(
        crossAxisAlignment: title == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 18 : 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: Txt.headline.copyWith(color: Tokens.textPrimary)),
                  const SizedBox(height: 3),
                ],
                Text(text, style: Txt.subhead.copyWith(color: compact ? Tokens.textPrimary : Tokens.textSecondary, height: 1.4)),
                if (action != null) ...[
                  const SizedBox(height: 6),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact rounded status pill badge.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.7),
      ),
      child: Text(text, style: Txt.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

/// Titled glass section card used in guides and setup steps.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.icon, required this.title, required this.children, this.iconColor = Tokens.accent});

  final IconData icon;
  final String title;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon, iconColor, size: 28),
              const SizedBox(width: 10),
              Text(title, style: Txt.headline),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------- Navigation & overlays
/// Slide-in page route supporting interactive edge swipe-back.
PageRoute<T> appleRoute<T>(WidgetBuilder builder) => CupertinoPageRoute<T>(builder: builder);

/// Bottom modal picker sheet; returns selected key or null if dismissed.
Future<T?> showApplePicker<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  T? selected,
  Map<T, String>? leading,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: Text(title, style: Txt.footnote.copyWith(fontFamily: 'IBMPlexSansArabic', color: Tokens.textSecondary)),
      actions: [
        for (final entry in options.entries)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheet).pop(entry.key),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading?[entry.key] != null) ...[
                  Text(leading![entry.key]!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(
                  entry.value,
                  style: Txt.body.copyWith(
                    fontFamily: 'IBMPlexSansArabic',
                    color: entry.key == selected ? Tokens.accent : Tokens.textPrimary,
                    fontWeight: entry.key == selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheet).pop(),
        child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
      ),
    ),
  );
}

/// Confirmation alert dialog; returns true if confirmed.
Future<bool> confirmApple(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialog) => CupertinoAlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
      content: Text(message, style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(action, style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Brief floating toast banner at the bottom of the screen.
void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message, textAlign: TextAlign.center)));
}

// ---------------------------------------------------------------------------------------------- Logo & splash
/// App icon mark with rounded corners and subtle glow.
class GtLogo extends StatelessWidget {
  const GtLogo({super.key, this.size = 64, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: glow
            ? [
                BoxShadow(color: Tokens.accent.withValues(alpha: 0.45), blurRadius: size * 0.38, spreadRadius: 1),
                BoxShadow(color: Tokens.purple.withValues(alpha: 0.25), blurRadius: size * 0.55),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// Splash screen shown during initial startup.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  /// Minimum duration so the launch animation completes cleanly.
  static const minimum = Duration(milliseconds: 900);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GlassBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseRings(controller: controller, child: const GtLogo(size: 96)),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: CurvedAnimation(parent: controller, curve: const Interval(0.25, 0.8)),
                  child: Column(
                    children: [
                      const Text('GameTranslator', style: Txt.title1),
                      const SizedBox(height: 6),
                      Text('ترجمة فورية للألعاب على التلفاز', style: Txt.subhead.copyWith(color: Tokens.textSecondary)),
                    ],
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

/// Expanding glow rings around the logo on the splash screen.
class _PulseRings extends StatelessWidget {
  const _PulseRings({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(controller.value);
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96 + t * 54,
                height: 96 + t * 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Tokens.accent.withValues(alpha: (1 - t) * 0.45), width: 1.5),
                ),
              ),
              child,
            ],
          ),
        );
      },
    );
  }
}
