// SPDX-License-Identifier: AGPL-3.0-only
// Installing the TV app from the phone: platform channel bridge and error messages for tvinstall/TvInstallChannel.
import 'package:flutter/services.dart';

enum TvKind { lg, samsung, android }

extension TvKindText on TvKind {
  String get id => name;

  String get title => switch (this) {
        TvKind.lg => 'LG',
        TvKind.samsung => 'Samsung',
        TvKind.android => 'Android TV / Google TV',
      };
}

TvKind? tvKindOf(String? id) => switch (id) {
      'lg' => TvKind.lg,
      'samsung' => TvKind.samsung,
      'android' => TvKind.android,
      _ => null,
    };

class FoundTv {
  const FoundTv(this.kind, this.host, this.name, this.ready);

  final TvKind kind;
  final String host;
  final String name;

  /// Installation port open: Developer Mode on LG, ADB debugging on Android.
  final bool ready;
}

class SavedTv {
  const SavedTv(this.kind, this.host, this.name, this.version);

  final TvKind kind;
  final String host;
  final String name;
  final String? version;
}

class TvCheck {
  const TvCheck(this.ready, this.keyServer, this.hasKey);

  final bool ready;
  final bool keyServer;

  /// LG: TV key is already saved, no passphrase prompt needed.
  final bool hasKey;
}

class TvInstallResult {
  const TvInstallResult({required this.ok, this.version, this.installed = false, this.launched = false, this.hoursLeft, this.error, this.detail});

  final bool ok;
  final String? version;

  /// false: TV version was already up to date, app was simply launched.
  final bool installed;
  final bool launched;

  /// Remaining hours of LG Developer Mode session.
  final int? hoursLeft;
  final String? error;
  final String? detail;
}

class TvBridge {
  static const _channel = MethodChannel('gt/tv');
  static const _events = EventChannel('gt/tv/events');

  /// Installation stages: connecting, approve, checking, key, `uploading:percent`, installing, verifying, launching.
  static Stream<String> get stages => _events.receiveBroadcastStream().map((event) => ((event as Map)['stage'] as String?) ?? '');

  /// Bundled TV package versions (brand -> version).
  static Future> bundled() async {
    final map = await _channel.invokeMethod>('bundled') ?? {};
    final result = <TvKind, String>{};
    for (final entry in map.entries) {
      final kind = tvKindOf(entry.key as String?);
      if (kind != null) result[kind] = entry.value as String;
    }
    return result;
  }

  static Future<String?> phoneAddress() => _channel.invokeMethod<String>('phoneAddress');

  static Future<SavedTv?> saved() async {
    final map = await _channel.invokeMethod>('saved');
    final kind = tvKindOf(map?['brand'] as String?);
    if (map == null || kind == null) return null;
    return SavedTv(kind, map['host'] as String? ?? '', map['name'] as String? ?? '', map['version'] as String?);
  }

  static Future<void> forget() => _channel.invokeMethod('forget');

  /// Normalizes a manually entered IP/host string; returns null if invalid.
  static Future<String?> normalize(String text) => _channel.invokeMethod<String>('normalize', text);

  static Future<List<FoundTv>> find(TvKind kind) async {
    final list = await _channel.invokeMethod<List<Object?>>('find', kind.id) ?? [];
    return [
      for (final item in list.cast>())
        FoundTv(kind, item['host'] as String, item['name'] as String? ?? kind.title, item['ready'] as bool? ?? false),
    ];
  }

  static Future<TvCheck> check(TvKind kind, String host) async {
    final map = await _channel.invokeMethod>('check', {'brand': kind.id, 'host': host}) ?? {};
    return TvCheck(map['ready'] as bool? ?? false, map['keyServer'] as bool? ?? false, map['hasKey'] as bool? ?? false);
  }

  static Future<TvInstallResult> install(TvKind kind, String host, {String name = '', String? passphrase, bool force = false}) async {
    final map = await _channel.invokeMethod>(
          'install',
          {'brand': kind.id, 'host': host, 'name': name, 'passphrase': passphrase, 'force': force},
        ) ??
        {};
    return TvInstallResult(
      ok: map['ok'] as bool? ?? false,
      version: map['version'] as String?,
      installed: map['installed'] as bool? ?? false,
      launched: map['launched'] as bool? ?? false,
      hoursLeft: (map['hoursLeft'] as num?)?.toInt(),
      error: map['error'] as String?,
      detail: map['detail'] as String?,
    );
  }

  static Future<void> cancel() => _channel.invokeMethod('cancel');
}

/// Human-readable error title and troubleshooting hint.
({String title, String fix}) tvErrorText(String? error, TvKind kind) {
  final android = kind == TvKind.android;
  return switch (error) {
    'UNREACHABLE' => android
        ? (
            title: 'التلفاز لا يستجيب',
            fix: 'تأكد أن التلفاز يعمل ومتصل بنفس شبكة Wi-Fi، وأن خيار "تصحيح أخطاء USB / الشبكة" مفعّل في خيارات المطوّر. '
                'بعض الشاشات تغلق هذا الخيار بعد إعادة التشغيل؛ فعّله وأعد المحاولة.',
          )
        : (
            title: 'التلفاز لا يستجيب',
            fix: 'تأكد أن التلفاز يعمل ومتصل بنفس شبكة Wi-Fi، وأن "Dev Mode Status" مفعّل داخل تطبيق Developer Mode؛ '
                'بعد تفعيله يعيد التلفاز التشغيل، انتظر حتى يكتمل ثم أعد المحاولة.',
          ),
    'KEY_SERVER_OFF' => (
        title: 'خدمة Key Server متوقفة',
        fix: 'افتح تطبيق Developer Mode على التلفاز، فعّل "Key Server" واترك التطبيق مفتوحاً على الشاشة، ثم أعد المحاولة.',
      ),
    'WRONG_PASSPHRASE' => (
        title: 'رمز المرور غير صحيح',
        fix: 'أعد إدخال رمز "Passphrase" المكون من 6 أحرف الظاهر أسفل يسار شاشة Developer Mode في التلفاز. '
            'انتبه للفرق بين 0 (صفر) وحرف O، وبين 1 وحرف I.',
      ),
    'KEY_REFUSED' => (
        title: 'رفض التلفاز مفتاح الاتصال',
        fix: 'عند إيقاف وضع المطوّر وإعادة تشغيله يُنشئ التلفاز مفتاحاً جديداً. فعّل Key Server وأعد إدخال الرمز.',
      ),
    'NOT_APPROVED' => (
        title: 'لم يتم منح الإذن على التلفاز',
        fix: 'أعد المحاولة. عند ظهور رسالة "هل تريد السماح بتصحيح أخطاء USB؟" على شاشة التلفاز، حدد "السماح دائماً من هذا الجهاز" '
            'واضغط "سماح". تبقى الرسالة على الشاشة لدقيقة ونصف تقريباً.',
      ),
    'NOT_ENOUGH_SPACE' => (
        title: 'لا توجد مساحة كافية على التلفاز',
        fix: 'احذف تطبيقاً غير مستخدم من التلفاز ثم أعد المحاولة.',
      ),
    'CONNECTION_LOST' => (
        title: 'انقطع الاتصال',
        fix: 'انقطع الاتصال بالتلفاز أثناء التثبيت. أبقِ شاشة الهاتف مفتوحة ومتصلة بشبكة Wi-Fi وأعد المحاولة.',
      ),
    'TOO_OLD' => (
        title: 'إصدار التلفاز قديم',
        fix: 'تطبيق GameTranslator TV لا يدعم إصدار النظام الحالي على هذا التلفاز.',
      ),
    'PACKAGE_MISSING' => (
        title: 'حزمة التلفاز غير موجودة',
        fix: 'تطبيق الهاتف الحالي لا يحتوي على حزمة التلفاز. ثبّت أحدث إصدار من التطبيق.',
      ),
    'CANCELLED' => (title: 'تم إيقاف التثبيت', fix: 'يمكنك إعادة البدء عندما تكون جاهزاً.'),
    _ => (
        title: 'تعذّر تثبيت تطبيق التلفاز',
        fix: 'أعد المحاولة. إعادة تشغيل التلفاز تحل معظم مشاكل التثبيت المعلّقة. إذا استمرت المشكلة أرسل رسالة الخطأ الظاهرة أدناه.',
      ),
  };
}

/// Arabic label for each TV installation stage.
String tvStageText(String stage) {
  if (stage.startsWith('uploading:')) return 'جارٍ إرسال التطبيق إلى التلفاز… %${stage.substring(10)}';
  return switch (stage) {
    'connecting' => 'جارٍ الاتصال بالتلفاز…',
    'approve' => 'بانتظار الموافقة على شاشة التلفاز…',
    'checking' => 'جارٍ التحقق من الإصدار على التلفاز…',
    'key' => 'جارٍ جلب مفتاح الاتصال من التلفاز…',
    'installing' => 'جارٍ التثبيت على التلفاز…',
    'verifying' => 'جارٍ التحقق من التثبيت…',
    'launching' => 'جارٍ تشغيل التطبيق على التلفاز…',
    _ => 'جارٍ التحضير…',
  };
}
