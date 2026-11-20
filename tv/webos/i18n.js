// SPDX-License-Identifier: AGPL-3.0-only
(function () {
  'use strict';

  var TEXTS = {
    ar: {
      waiting: 'افتح تطبيق GameTranslator على جهازك.',
      waitingHint: 'سيعثر التطبيق على هذا التلفاز ويرسل الترجمة إلى هنا.',
      panelTitle: 'GameTranslator',
      hdmi: 'HDMI',
      lastSubtitle: 'آخر ترجمة',
      diagnostics: 'التشخيص',
      server: 'التطبيق',
      connection: 'الاتصال',
      loading: '(جارٍ التحميل)',
      videoReady: '(تم استلام الصورة)',
      playing: '(قيد التشغيل)',
      inputError: '(خطأ: تعذر فتح المدخل)',
      sourceError: '(خطأ: المصدر غير مدعوم)',
      auto: 'تلقائي',
      consoleNotFound: 'لم يتم العثور على الجهاز',
      noEventSource: 'هذا التلفاز غير مدعوم (EventSource غير متوفر)',
      connecting: 'جارٍ الاتصال…',
      connected: 'متصل',
      reconnecting: 'انقطع الاتصال، جارٍ إعادة المحاولة…',
      none: '—',
      keys: 'موافق: هذه اللوحة · ◀▶: مدخل HDMI (عند فتح اللوحة) · 1–4: مدخل HDMI · 0: بحث تلقائي عن الجهاز · ▲▼: تحريك الترجمة للأعلى/للأسفل · أحمر: ترجمة تجريبية · أزرق: عرض توضيحي · أخضر: هذه اللوحة',
      localTest: 'اختبار: هل يظهر هذا النص فوق اللعبة؟',
      positionPreview: 'ستظهر الترجمة هنا',
      demoButton: 'مشاهدة العرض التجريبي',
      demoBadge: 'تجريبي',
      demoHint: 'مثال: تظهر ترجمة اللعبة هنا باللغة العربية. اضغط رجوع للخروج.'
    },
    tr: {
      waiting: 'Bilgisayarınızda GameTranslator uygulamasını açın.',
      waitingHint: 'Uygulama bu TV\'yi bulup altyazıları buraya gönderecek.',
      panelTitle: 'GameTranslator',
      hdmi: 'HDMI',
      lastSubtitle: 'Son altyazı',
      diagnostics: 'Tanı',
      server: 'Uygulama',
      connection: 'Bağlantı',
      loading: '(yükleniyor)',
      videoReady: '(görüntü geldi)',
      playing: '(oynatılıyor)',
      inputError: '(hata: giriş açılamadı)',
      sourceError: '(hata: kaynak desteklenmiyor)',
      auto: 'otomatik',
      consoleNotFound: 'konsol bulunamadı',
      noEventSource: 'Bu TV desteklenmiyor (EventSource yok)',
      connecting: 'bağlanıyor…',
      connected: 'bağlı',
      reconnecting: 'bağlantı yok, yeniden deneniyor…',
      none: '—',
      keys: 'Tamam: bu panel · ◀▶: HDMI girişi (panel açıkken) · 1–4: HDMI girişi · 0: konsolu otomatik bul · ▲▼: altyazıyı yukarı/aşağı taşı · Kırmızı: test altyazısı · Mavi: demo · Yeşil: bu panel',
      localTest: 'Test: bu yazı oyunun üstünde görünüyor mu?',
      positionPreview: 'Altyazı burada görünecek',
      demoButton: 'Demoyu izle',
      demoBadge: 'DEMO',
      demoHint: 'Örnek: oyunun İngilizce altyazısı Türkçe olarak burada görünür. Çıkmak için Geri.'
    },
    en: {
      waiting: 'Open the GameTranslator app on your computer.',
      waitingHint: 'The app will find this TV and send subtitles here.',
      panelTitle: 'GameTranslator',
      hdmi: 'HDMI',
      lastSubtitle: 'Last subtitle',
      diagnostics: 'Diagnostics',
      server: 'App',
      connection: 'Connection',
      loading: '(loading)',
      videoReady: '(picture received)',
      playing: '(playing)',
      inputError: '(error: input could not be opened)',
      sourceError: '(error: source not supported)',
      auto: 'automatic',
      consoleNotFound: 'console not found',
      noEventSource: 'This TV is not supported (no EventSource)',
      connecting: 'connecting…',
      connected: 'connected',
      reconnecting: 'disconnected, retrying…',
      none: '—',
      keys: 'OK: this panel · ◀▶: HDMI input (panel open) · 1–4: HDMI input · 0: find console automatically · ▲▼: move subtitles up/down · Red: test subtitle · Blue: demo · Green: this panel',
      localTest: 'Test: is this text shown on top of the game?',
      positionPreview: 'Subtitles will appear here',
      demoButton: 'Watch the demo',
      demoBadge: 'DEMO',
      demoHint: 'Example: the game\'s English subtitles appear here. Press Back to exit.'
    }
  };

  var navLang = (navigator.language || 'en').toLowerCase();
  var lang = navLang.indexOf('ar') === 0 ? 'ar' : (navLang.indexOf('tr') === 0 ? 'tr' : 'en');

  if (document && document.documentElement) {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  }

  window.t = function (key) {
    return (TEXTS[lang] && TEXTS[lang][key]) || TEXTS.en[key] || key;
  };

  window.applyI18n = function () {
    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].textContent = window.t(nodes[i].getAttribute('data-i18n'));
    }
  };
})();
