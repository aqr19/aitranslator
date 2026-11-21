// SPDX-License-Identifier: AGPL-3.0-only
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'bridge.dart';
import 'home_page.dart';
import 'intro_page.dart';
import 'setup_page.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const GameTranslatorApp());
}

/// Dark glass design tokens: system colors, translucent surfaces, and typography scale.
class Tokens {
  /// Base background color; ambient glows are drawn over this in [GlassBackground].
  static const background = Color(0xFF05070D);

  /// Translucent glass surfaces. Cards use [glassFill] gradient instead of flat colors.
  static const surface = Color(0x1AFFFFFF);
  static const surfaceHigh = Color(0x29FFFFFF);

  /// Glass borders and row dividers.
  static const border = Color(0x2EFFFFFF);
  static const separator = Color(0x24FFFFFF);

  /// Recessed fields such as text inputs and segmented controls.
  static const inset = Color(0x33000000);

  /// Popups and sheets: nearly opaque dark surface so underlying text does not bleed through.
  static const sheet = Color(0xF21C1C1E);

  /// Primary and secondary text colors.
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99EBEBF5);

  /// Accent and semantic system colors.
  static const accent = Color(0xFF0A84FF);
  static const accentText = Color(0xFF0A84FF);
  static const accentSoft = Color(0x400A84FF);
  static const glow = Color(0xFF64D2FF);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFF9F0A);
  static const danger = Color(0xFFFF453A);
  static const purple = Color(0xFFBF5AF2);
  static const indigo = Color(0xFF5E5CE6);
  static const teal = Color(0xFF40C8E0);
  static const gray = Color(0xFF8E8E93);

  /// Glass card gradient: brighter top-left highlight fading toward bottom-right.
  static const glassFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2BFFFFFF), Color(0x12FFFFFF)],
  );
}

/// Typography scale using IBM Plex Sans Arabic.
class Txt {
  static const largeTitle = TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15);
  static const title1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.18);
  static const title2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.25);
  static const title3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.25);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.3);
  static const body = TextStyle(fontSize: 17, fontWeight: FontWeight.w400, letterSpacing: -0.3, height: 1.3);
  static const callout = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 1.32);
  static const subhead = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: -0.2, height: 1.35);
  static const footnote = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.05, height: 1.38);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35);
}

class GameTranslatorApp extends StatelessWidget {
  const GameTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: Tokens.accent, brightness: Brightness.dark).copyWith(
      primary: Tokens.accent,
      onPrimary: Colors.white,
      secondary: Tokens.accent,
      surface: Tokens.background,
      onSurface: Tokens.textPrimary,
      onSurfaceVariant: Tokens.textSecondary,
      surfaceContainerLowest: Tokens.background,
      surfaceContainerLow: Tokens.sheet,
      surfaceContainer: Tokens.sheet,
      surfaceContainerHigh: Tokens.sheet,
      surfaceContainerHighest: Tokens.sheet,
      outline: Tokens.border,
      outlineVariant: Tokens.separator,
      error: Tokens.danger,
    );
    const capsule = StadiumBorder();
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: width));
    return MaterialApp(
      title: 'GameTranslator',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppleScroll(),
      theme: ThemeData(
        colorScheme: scheme,
        fontFamily: 'IBMPlexSansArabic',
        scaffoldBackgroundColor: Tokens.background,
        splashFactory: NoSplash.splashFactory,
        highlightColor: const Color(0x1FFFFFFF),
        textTheme: const TextTheme(bodyMedium: Txt.body, bodyLarge: Txt.body, titleMedium: Txt.body),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Tokens.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: Tokens.textPrimary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            shape: capsule,
            backgroundColor: Tokens.accent,
            foregroundColor: Colors.white,
            textStyle: Txt.headline.copyWith(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 50),
            backgroundColor: Tokens.surface,
            shape: capsule,
            textStyle: Txt.headline.copyWith(fontFamily: 'IBMPlexSansArabic'),
            foregroundColor: Tokens.textPrimary,
            side: const BorderSide(color: Tokens.border),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Tokens.accent, textStyle: Txt.body.copyWith(fontFamily: 'IBMPlexSansArabic')),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Tokens.inset,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: const TextStyle(color: Tokens.textSecondary),
          hintStyle: const TextStyle(color: Color(0x4DEBEBF5)),
          helperStyle: Txt.footnote.copyWith(color: Tokens.textSecondary),
          border: field(Tokens.border),
          enabledBorder: field(Tokens.border),
          focusedBorder: field(Tokens.accent, 1.5),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Tokens.sheet,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Tokens.sheet,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: Color(0x4DEBEBF5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Tokens.sheet,
          contentTextStyle: Txt.subhead.copyWith(fontFamily: 'IBMPlexSansArabic', color: Tokens.textPrimary),
          shape: const StadiumBorder(side: BorderSide(color: Tokens.border)),
        ),
        dividerTheme: const DividerThemeData(color: Tokens.separator, thickness: 0.6, space: 0.6),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: Tokens.accent),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RootPage(),
    );
  }
}

/// Bouncing scroll physics without Android edge glow.
class _AppleScroll extends MaterialScrollBehavior {
  const _AppleScroll();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Shows intro on first launch, then setup (PSN sign-in and PS5 pairing), and finally the home screen.
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  SetupInfo? setup;
  late final AppLifecycleListener lifecycle;

  /// Whether the splash delay has finished so the opening animation is not cut short.
  bool splashDone = false;

  @override
  void initState() {
    super.initState();
    // Reload setup state on app resume in case pairing changed in the background.
    lifecycle = AppLifecycleListener(onResume: reload);
    reload();
    Future<void>.delayed(SplashView.minimum, () {
      if (mounted) setState(() => splashDone = true);
    });
  }

  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final info = await Bridge.setup();
    if (mounted) setState(() => setup = info);
  }

  Future<void> finishIntro() async {
    await Bridge.setIntroSeen(true);
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final info = setup;
    final Widget page;
    if (info == null || !splashDone) {
      page = const SplashView(key: ValueKey('splash'));
    } else if (!info.ready && !info.introSeen) {
      page = IntroPage(key: const ValueKey('intro'), onDone: finishIntro);
    } else if (!info.ready) {
      page = SetupPage(key: const ValueKey('setup'), setup: info, onChanged: reload);
    } else {
      page = HomePage(key: const ValueKey('home'), setup: info, onSetupChanged: reload);
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 420), child: page);
  }
}
