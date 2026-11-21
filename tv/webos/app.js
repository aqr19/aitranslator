// SPDX-License-Identifier: AGPL-3.0-only
// GameTranslator TV client (shared across webOS, Tizen, and Android TV).
// Displays full-screen HDMI input and renders live subtitles sent by GameTranslator.
// Platform-specific hooks live in platform.js; written in ES5 for broad TV WebView compatibility.
(function () {
  'use strict';

  // TV app version kept in sync across app manifests and build configs.
  var APP_VERSION = '1.0.5';
  var t = window.t;
  var config = window.GAMETRANSLATOR_CONFIG || window.GAMETRANSLATOR_CONFIG || {};
  var platform = window.GAMETRANSLATOR_PLATFORM || window.GAMETRANSLATOR_PLATFORM;
  var KEY = { RED: 403, GREEN: 404, BLUE: 406, LEFT: 37, UP: 38, RIGHT: 39, DOWN: 40, OK: 13, BACK: platform.backKey };

  var server = null;
  var eventSource = null;
  // Uses persisted remote-selected HDMI port if set; otherwise auto-detects console.
  var savedPort = Number(load('hdmi'));
  var hdmiPort = savedPort || 1;

  var bottomPercent = 7;
  // Subtitle placement mode: cover, above, below, or fixed.
  // Falls back to fixed when placement metadata is not provided.
  var PLACEMENTS = { cover: 1, above: 1, below: 1, fixed: 1 };
  var placement = 'fixed';
  // Normalized bounding box of the source subtitle region if known, otherwise null.
  var currentBox = null;
  // Source subtitle box for cover fitting, configured base font size, and whether fit mode is active.
  // Current fit state flag.
  var currentSource = null;
  var baseFontSize = 0;
  var fitted = false;
  // Normalized line height of the source subtitle, or 0 if unknown.
  var currentLine = 0;
  var coverBackground = '';
  // Speaker label highlight color; disabled when empty.
  var speakerColor = '';

  // Minimum hold duration for previous subtitle lines before replacement.
  var PREVIOUS_HOLD_MS = 2500;
  var shownAt = 0;
  var previousTimer = null;

  var hideTimer = null;
  var panelTimer = null;

  // Prevents premature clear events from flashing out fresh subtitles before minimum hold expires.
  // Bounded hold timestamp for incoming subtitle lines.
  var HOLD_MAX_MS = 5000;
  var holdUntil = 0;
  // Grace period before clearing active subtitles after an SSE disconnect.
  var DROP_HIDE_MS = 6000;
  var dropTimer = null;

  // Diagnostics counters displayed in the status panel for troubleshooting.
  var diag = { subtitles: 0, clears: 0, drops: 0, backgrounded: 0, lastHide: '-', place: '-', error: '' };

  function $(id) { return document.getElementById(id); }

  function renderDiag() {
    var el = $('st-diag');
    if (!el) return;
    el.textContent = 'sub ' + diag.subtitles + ' · clear ' + diag.clears + ' · drop ' + diag.drops +
      ' · bg ' + diag.backgrounded + ' · hide ' + diag.lastHide + ' · ' + diag.place +
      (window.__screenSaverStatus ? ' · saver ' + window.__screenSaverStatus : '') +
      (diag.error ? ' · err ' + diag.error : '');
  }

  function noteError(message) {
    diag.error = String(message).slice(0, 120);
    renderDiag();
  }

  window.onerror = function (message, source, line) {
    noteError(message + ' @' + line);
    return false;
  };

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) diag.backgrounded++;
    renderDiag();
  });

  function load(key) {
    try { return window.localStorage.getItem('gametranslator.' + key) || window.localStorage.getItem('gametranslator.' + key); } catch (e) { return null; }
  }

  function save(key, value) {
    try { window.localStorage.setItem('gametranslator.' + key, String(value)); } catch (e) {}
  }

  function setStatus(id, text, cls) {
    var el = $(id);
    el.textContent = text;
    el.className = cls || '';
  }

  // --- Launch parameters ---

  function parseParams(raw) {
    if (!raw) return {};
    if (typeof raw === 'object') return raw;
    try {
      return JSON.parse(raw) || {};
    } catch (e) {
      try {
        var unescaped = raw.replace(/\\"/g, '"');
        return JSON.parse(unescaped) || {};
      } catch (e2) {
        var m = /"server"\s*:\s*"([^"]+)"/.exec(raw) || /server[:=]\s*(\S+)/.exec(raw);
        if (m) return { server: m[1] };
        return {};
      }
    }
  }

  // Applies server and HDMI preferences from launch params and reconnects if server changed.
  function applyParams(params) {
    if (params.hdmi >= 1 && params.hdmi <= 4) {
      hdmiPort = Number(params.hdmi);
      save('hdmi', hdmiPort);
      showHdmi(hdmiPort);
    }
    if (params.server && params.server !== server) {
      save('server', params.server);
      connect(params.server);
    }
  }

  // --- HDMI input ---

  function showHdmi(port) {
    setStatus('st-hdmi', String(port));
    var statuses = {
      loading: ['loading', 'muted'],
      ready: ['videoReady', 'ok'],
      playing: ['playing', 'ok'],
      inputError: ['inputError', 'bad'],
      sourceError: ['sourceError', 'bad']
    };
    platform.showHdmi(port, $('video-host'), function (kind) {
      setStatus('st-video', t(statuses[kind][0]), statuses[kind][1]);
    });
  }

  function autoSelectConsole(onNotFound) {
    platform.findConsolePort(function (port, label) {
      if (!port) return onNotFound && onNotFound();
      if (port !== hdmiPort) {
        hdmiPort = port;
        showHdmi(port);
      }
      setStatus('st-hdmi', port + ' — ' + label + ' (' + t('auto') + ')');
    });
  }

  // --- Subtitles ---

  // Validates and clamps normalized bounding box coordinates into [0, 1].
  function validBox(box) {
    if (!box || typeof box !== 'object') return null;
    var left = Number(box.left), top = Number(box.top), right = Number(box.right), bottom = Number(box.bottom);
    if (isNaN(left) || isNaN(top) || isNaN(right) || isNaN(bottom)) return null;
    left = Math.max(0, Math.min(0.98, left));
    right = Math.max(left + 0.01, Math.min(1.0, right));
    top = Math.max(0, Math.min(0.98, top));
    bottom = Math.max(top + 0.01, Math.min(1.0, bottom));
    return { left: left, top: top, right: right, bottom: bottom };
  }

  // paragraphs: renders multi-line quest/list text with preserved line breaks.
  function showSubtitle(text, duration, box, paragraphs, source, line) {
    // source: normalized source box used when fitting translations in cover mode.
    currentSource = paragraphs ? null : validBox(source);
    currentLine = typeof line === 'number' && line > 0 ? line : 0;
    // Replace previous subtitle directly so stacked boxes do not overlap.
    // Active line supersedes prior line.
    hidePrevious();
    shownAt = Date.now();
    holdUntil = shownAt + Math.min(HOLD_MAX_MS, 2000 + text.length * 60);
    currentBox = validBox(box);
    setSubtitleText($('subtitle-text'), text, paragraphs);
    $('subtitle-text').style.whiteSpace = paragraphs ? 'pre-line' : '';
    $('subtitle-text').style.textAlign = paragraphs ? 'right' : '';
    $('subtitle').className = '';
    layout();
    setStatus('st-last', text.length > 40 ? text.slice(0, 40) + '…' : text);
    notePlace();
    clearTimeout(hideTimer);
    // Enforce a sane minimum display duration so short/invalid durations do not flicker.
    var ms = duration > 0 ? Math.max(1000, duration) : Math.min(8000, 2000 + text.length * 60);
    hideTimer = setTimeout(function () { hideSubtitle('timer'); }, ms);
  }

  // Highlights speaker prefixes ("NAME: ") when speakerColor is configured.
  // Matches speaker names at line start or after sentence boundaries.
  var SPEAKER = /(^|[.!?…”"]\s+|\n)([A-Z\u0621-\u064A][^\s:.!?]*(?: [A-Z\u0621-\u064A][^\s:.!?]*){0,2}):(?=\s)/g;
  function setSubtitleText(el, text, paragraphs) {
    if (!speakerColor || paragraphs) {
      el.textContent = text;
      return;
    }
    el.textContent = '';
    var last = 0, match;
    SPEAKER.lastIndex = 0;
    while ((match = SPEAKER.exec(text)) !== null) {
      var nameStart = match.index + match[1].length;
      if (nameStart > last) el.appendChild(document.createTextNode(text.slice(last, nameStart)));
      var name = document.createElement('span');
      name.style.color = speakerColor;
      name.textContent = match[2] + ':';
      el.appendChild(name);
      last = SPEAKER.lastIndex;
    }
    if (last < text.length) el.appendChild(document.createTextNode(text.slice(last)));
  }

  // Records rendered subtitle bounds and visibility for diagnostics.
  function notePlace() {
    var el = $('subtitle-text');
    var rect = el.getBoundingClientRect();
    var height = document.documentElement.clientHeight || window.innerHeight || 0;
    diag.place = 'y ' + Math.round(rect.top) + '-' + Math.round(rect.bottom) + '/' + height + ' ' +
      window.getComputedStyle($('subtitle')).visibility + ' f' + window.getComputedStyle(el).fontSize;
    renderDiag();
  }

  // Hides active subtitle and records the hide reason and elapsed duration.
  function hideSubtitle(reason) {
    clearTimeout(hideTimer);
    if ($('subtitle').className !== 'hidden') {
      diag.lastHide = (reason || '?') + ' ' + (Date.now() - shownAt) + 'ms';
      renderDiag();
    }
    $('subtitle').className = 'hidden';
    $('subtitle-cover').className = 'hidden';
    hidePrevious();
  }

  // Handles clear events, deferring removal until holdUntil if still within minimum hold window.
  function onClear() {
    diag.clears++;
    renderDiag();
    var left = holdUntil - Date.now();
    if (left <= 0 || $('subtitle').className === 'hidden') return hideSubtitle('clear');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(function () { hideSubtitle('clear-held'); }, left);
  }

  function showPrevious(text) {
    $('subtitle-prev-text').textContent = text;
    $('subtitle-prev').className = '';
    clearTimeout(previousTimer);
    previousTimer = setTimeout(hidePrevious, PREVIOUS_HOLD_MS);
  }

  function hidePrevious() {
    clearTimeout(previousTimer);
    $('subtitle-prev').className = 'hidden';
  }

  // --- Full-screen translation ---
  // Renders positioned full-screen OCR translation items over matching screen regions.
  // Scales font size down if translated text exceeds the target box height.

  var screenTimer = null;
  var SCREEN_PAD = 0.004;
  var SCREEN_MIN_FONT = 14;

  function showScreen(items, duration) {
    var host = $('screen');
    // Clear single-line subtitle overlay when full-screen items arrive.
    hideSubtitle('screen');
    host.innerHTML = '';
    host.className = '';
    var width = window.innerWidth || 1920;
    var height = window.innerHeight || 1080;
    for (var i = 0; i < (items || []).length; i++) {
      var item = items[i];
      var box = validBox(item && item.box);
      if (!box || !item.text) continue;
      var el = document.createElement('div');
      el.className = item.paragraphs === true ? 'item paragraphs' : 'item';
      el.textContent = item.text;
      var left = Math.max(0, box.left - SCREEN_PAD);
      var top = Math.max(0, box.top - SCREEN_PAD);
      var boxHeight = (box.bottom - box.top + 2 * SCREEN_PAD) * height;
      el.style.left = (left * 100) + '%';
      el.style.top = (top * 100) + '%';
      el.style.width = Math.max(80, (Math.min(1, box.right + SCREEN_PAD) - left) * width) + 'px';
      el.style.minHeight = Math.round(boxHeight) + 'px';
      var line = typeof item.line === 'number' && item.line > 0 ? item.line * height : box.bottom * height - box.top * height;
      var size = Math.max(SCREEN_MIN_FONT, Math.min(96, Math.round(line * 0.95)));
      el.style.fontSize = size + 'px';
      host.appendChild(el);
      // Allow moderate vertical expansion first, then shrink font size to fit.
      var limit = Math.max(boxHeight * 1.5, line * 2.6);
      while (el.scrollHeight > limit && size > SCREEN_MIN_FONT) {
        size -= 2;
        el.style.fontSize = size + 'px';
      }
    }
    clearTimeout(screenTimer);
    screenTimer = setTimeout(hideScreen, duration || 20000);
  }

  function hideScreen() {
    clearTimeout(screenTimer);
    $('screen').className = 'hidden';
    $('screen').innerHTML = '';
  }

  // Subtitle vertical position can be adjusted from the app or remote UP/DOWN keys.
  // Most recent position adjustment takes precedence until changed again.
  function setBottom(percent) {
    bottomPercent = Math.max(0, Math.min(85, percent));
    layout();
  }

  // Positions subtitle overlay according to placement mode; falls back to fixed when box is unknown.
  function layout() {
    var el = $('subtitle');
    var cover = $('subtitle-cover');
    var box = placement === 'fixed' ? null : currentBox;

    el.style.left = '4%';
    el.style.right = '4%';
    el.style.top = 'auto';
    el.style.bottom = Math.max(2, Math.min(88, bottomPercent)) + '%';
    el.style.transform = 'none';
    el.style.webkitTransform = 'none';
    cover.className = 'hidden';
    unfit();

    // Do not show cover overlay without an active subtitle and valid box.
    if (!box || el.className === 'hidden') return;

    var mode = placement;
    // Flip above/below if too close to bottom or top screen edge.
    if (mode === 'below' && box.bottom > 0.88) mode = 'above';
    if (mode === 'above' && box.top < 0.12) mode = 'below';

    if (mode === 'cover' && currentSource) {
      fitToSource(el, cover, currentSource);
    } else if (mode === 'cover') {
      // Dark backdrop covering the source subtitle region.
      var padX = 0.02; // Yatayda %2 pay
      var padY = 0.015; // Dikeyde %1.5 pay
      var cLeft = Math.max(0.01, box.left - padX);
      var cTop = Math.max(0.01, box.top - padY);
      var cRight = Math.min(0.99, box.right + padX);
      var cBottom = Math.min(0.99, box.bottom + padY);

      cover.style.left = (cLeft * 100).toFixed(2) + '%';
      cover.style.top = (cTop * 100).toFixed(2) + '%';
      cover.style.width = ((cRight - cLeft) * 100).toFixed(2) + '%';
      cover.style.height = ((cBottom - cTop) * 100).toFixed(2) + '%';
      cover.className = '';

      // Vertically center translated subtitle over the cover box.
      var centerBottom = (1.0 - (box.top + box.bottom) / 2.0) * 100.0;
      el.style.top = 'auto';
      el.style.bottom = Math.max(2, Math.min(92, centerBottom)).toFixed(2) + '%';
      el.style.transform = 'translateY(50%)';
      el.style.webkitTransform = 'translateY(50%)';
    } else if (mode === 'above') {
      // Position just above the source subtitle box.
      cover.className = 'hidden';
      var aboveBottom = (1.0 - box.top) * 100.0 + 1.5;
      el.style.top = 'auto';
      el.style.bottom = Math.max(5, Math.min(94, aboveBottom)).toFixed(2) + '%';
      el.style.transform = 'none';
      el.style.webkitTransform = 'none';
    } else if (mode === 'below') {
      // Position just below the source subtitle box.
      cover.className = 'hidden';
      var belowTop = box.bottom * 100.0 + 1.5;
      el.style.bottom = 'auto';
      el.style.top = Math.max(5, Math.min(94, belowTop)).toFixed(2) + '%';
      el.style.transform = 'none';
      el.style.webkitTransform = 'none';
    }
  }

  // Fits translated text inside the source subtitle box while selecting the largest readable font size.
  // Clamps font size relative to configured base size and source line height.
  // Expands cover backdrop if text still overflows at minimum font size.
  function fitToSource(el, cover, box) {
    var padX = 0.008, padY = 0.006;
    var left = Math.max(0, box.left - padX), right = Math.min(1, box.right + padX);
    var top = Math.max(0, box.top - padY), bottom = Math.min(1, box.bottom + padY);
    // Enforce a minimum width so short single-word boxes remain readable.
    var minWidth = 0.16;
    if (right - left < minWidth) {
      var center = (left + right) / 2;
      left = Math.max(0, center - minWidth / 2);
      right = Math.min(1, center + minWidth / 2);
    }
    // Place cover first so rendered pixel bounds can be measured accurately.
    var place = function (l, t, r, b) {
      cover.style.left = (l * 100).toFixed(3) + '%';
      cover.style.top = (t * 100).toFixed(3) + '%';
      cover.style.width = ((r - l) * 100).toFixed(3) + '%';
      cover.style.height = ((b - t) * 100).toFixed(3) + '%';
    };
    place(left, top, right, bottom);
    // Use opaque backdrop in cover mode so source text does not bleed through.
    if (!fitted) coverBackground = cover.style.background;
    cover.style.background = 'rgb(10, 10, 12)';
    cover.className = '';
    var area = cover.getBoundingClientRect();
    var perX = area.width / (right - left), perY = area.height / (bottom - top);

    var text = $('subtitle-text');
    el.style.left = (left * 100).toFixed(3) + '%';
    el.style.right = ((1 - right) * 100).toFixed(3) + '%';
    el.style.bottom = 'auto';
    el.style.top = (((top + bottom) / 2) * 100).toFixed(3) + '%';
    el.style.transform = 'translateY(-50%)';
    el.style.webkitTransform = 'translateY(-50%)';
    text.style.padding = '0 6px';
    text.style.lineHeight = '1.2';

    // Compute font size bounds from source line height or base font size.
    var base = baseFontSize || 46;
    var low = Math.max(16, Math.round(base * 0.55));
    var high = currentLine > 0 ? Math.round(currentLine * perY * 1.05) : Math.round(base * 1.15);
    high = Math.max(low, Math.min(Math.round(base * 1.6), high));
    var fits = function (size) {
      text.style.fontSize = size + 'px';
      var rect = text.getBoundingClientRect();
      return rect.width <= area.width + 1 && rect.height <= area.height + 1;
    };
    var best = low;
    if (fits(high)) best = high;
    else if (fits(low)) {
      var a = low, b = high;
      while (b - a > 1) {
        var mid = Math.floor((a + b) / 2);
        if (fits(mid)) a = mid; else b = mid;
      }
      best = a;
    }
    text.style.fontSize = best + 'px';

    // Expand cover box slightly if text still exceeds bounds at minimum size.
    var rect = text.getBoundingClientRect();
    var growTop = Math.max(0, area.top - rect.top + 2) / perY, growBottom = Math.max(0, rect.bottom - area.bottom + 2) / perY;
    var growLeft = Math.max(0, area.left - rect.left + 2) / perX, growRight = Math.max(0, rect.right - area.right + 2) / perX;
    if (growTop || growBottom || growLeft || growRight)
      place(Math.max(0, left - growLeft), Math.max(0, top - growTop), Math.min(1, right + growRight), Math.min(1, bottom + growBottom));
    fitted = true;
  }

  // Restores base font size and default padding when leaving cover-fit mode.
  function unfit() {
    if (!fitted) return;
    fitted = false;
    var text = $('subtitle-text');
    $('subtitle-cover').style.background = coverBackground;
    text.style.padding = '';
    text.style.lineHeight = '';
    if (baseFontSize) text.style.fontSize = baseFontSize + 'px';
  }

  // Clamps bottom offset within safe screen bounds.
  function keepOnScreen(el, cover) {
    if (placement === 'fixed') {
      bottomPercent = Math.max(2, Math.min(85, bottomPercent));
      el.style.bottom = bottomPercent + '%';
    }
  }

  function applyStyle(style) {
    if (style.fontSize) {
      baseFontSize = style.fontSize;
      $('subtitle-text').style.fontSize = style.fontSize + 'px';
      $('subtitle-prev-text').style.fontSize = Math.round(style.fontSize * 0.8) + 'px';
    }
    if (style.color) {
      $('subtitle-text').style.color = style.color;
      $('subtitle-prev-text').style.color = style.color;
    }
    if (PLACEMENTS[style.placement]) placement = style.placement;
    if (typeof style.speakerColor === 'string') speakerColor = style.speakerColor;
    if (typeof style.background === 'number') {
      var alpha = Math.max(0, Math.min(100, style.background)) / 100;
      $('subtitle-text').style.background = 'rgba(0, 0, 0, ' + alpha + ')';
      $('subtitle-prev-text').style.background = 'rgba(0, 0, 0, ' + (alpha * 0.83).toFixed(2) + ')';
      var coverEl = $('subtitle-cover');
      // Keep cover box opaque to prevent underlying text bleed-through.
      if (coverEl) coverEl.style.background = 'rgb(10, 10, 12)';
    }
    if (typeof style.bold === 'boolean') {
      $('subtitle-text').style.fontWeight = style.bold ? '700' : '600';
      $('subtitle-prev-text').style.fontWeight = style.bold ? '700' : '600';
    }
    if (style.bottomPercent >= 0) {
      bottomPercent = Math.max(0, Math.min(92, Number(style.bottomPercent)));
    }
    layout();
  }

  function nudgeSubtitle(step) {
    // Remote vertical nudging applies only in fixed placement mode.
    if (placement !== 'fixed') return;
    setBottom(bottomPercent + step);
    save('bottom', bottomPercent);
    // Show a brief sample line if no subtitle is currently visible.
    if ($('subtitle').className === 'hidden') showSubtitle(t('positionPreview'), 2500);
  }

  // --- Server-Sent Events stream ---

  function onEvent(name, handler) {
    eventSource.addEventListener(name, function (e) {
      var data;
      try {
        data = JSON.parse(e.data);
      } catch (err) {
        noteError(name + ': bad json');
        return;
      }
      try {
        handler(data);
      } catch (err) {
        noteError(name + ': ' + err.message);
      }
    });
  }

  function connect(address) {
    if (demoRunning()) stopDemo();
    if (eventSource) eventSource.close();
    if (address !== server) failures = 0;
    server = address;
    $('waiting').className = 'hidden';
    setStatus('st-server', address);
    if (!window.EventSource) {
      setStatus('st-conn', t('noEventSource'), 'bad');
      return;
    }
    setStatus('st-conn', t('connecting'), 'muted');
    eventSource = new EventSource(address + '/events');
    eventSource.onopen = function () {
      failures = 0;
      cancelScan();
      clearTimeout(dropTimer);
      dropTimer = null;
      setStatus('st-conn', t('connected'), 'ok');
    };
    eventSource.onerror = function () {
      // Clear stale subtitles only if disconnect outlasts DROP_HIDE_MS.
      diag.drops++;
      renderDiag();
      if (dropTimer === null) {
        dropTimer = setTimeout(function () {
          dropTimer = null;
          hideSubtitle('drop');
          hideScreen();
        }, DROP_HIDE_MS);
      }
      setStatus('st-conn', t('reconnecting'), 'bad');
      // Host IP may have changed; record failure to trigger LAN scan if needed.
      noteFailure();
    };
    onEvent('subtitle', function (data) {
      diag.subtitles++;
      renderDiag();
      if (data.text) showSubtitle(data.text, data.duration, data.box, data.paragraphs === true, data.source, data.line);
    });
    onEvent('clear', onClear);
    onEvent('screen', function (data) { showScreen(data.items, data.duration); });
    onEvent('screen-clear', hideScreen);
    onEvent('style', applyStyle);
    onEvent('speech', function (data) { if (data.url) playSpeech(server + data.url); });
    onEvent('speech-stop', stopSpeech);
  }

  // --- Audio playback ---
  // Plays synthesized speech audio URLs pushed by the host.
  // Stops any currently playing audio before starting a new clip.

  var speech = null;

  function playSpeech(url) {
    stopSpeech();
    try {
      speech = new Audio(url);
      var played = speech.play();
      if (played && played.catch) played.catch(function () { speech = null; });
    } catch (e) {
      speech = null;
    }
  }

  function stopSpeech() {
    if (!speech) return;
    try { speech.pause(); } catch (e) { /* ignore */ }
    speech = null;
  }

  // --- LAN host discovery ---
  // Scans local subnets when no launch server is provided or saved host stops responding.
  // Checks TV local subnet first, then saved server subnet, falling back to 192.168.1.
  // Triggers a fast scan after FAILS_BEFORE_SCAN consecutive connection errors.
  // Falls back gracefully when platform.localAddress is unavailable.

  var SERVER_PORT = 8787;
  var SCAN_PARALLEL = 24;
  var SCAN_TIMEOUT_MS = 1200;
  var SCAN_PAUSE_MS = 30000;
  var SCAN_SOON_MS = 3000;
  var FAILS_BEFORE_SCAN = 3;
  var scanTimer = null;
  var scanDue = 0;
  var scanning = false;
  var failures = 0;

  // Preserve an earlier scheduled scan rather than pushing it further out.
  // Avoid resetting shorter backoff timers on repeated SSE retries.
  function scheduleScan(delay) {
    if (scanning) return;
    if (delay === undefined) delay = SCAN_PAUSE_MS;
    var due = Date.now() + delay;
    if (scanTimer !== null && scanDue <= due) return;
    clearTimeout(scanTimer);
    scanDue = due;
    scanTimer = setTimeout(function () {
      scanTimer = null;
      scanForServer();
    }, delay);
  }

  function cancelScan() {
    clearTimeout(scanTimer);
    scanTimer = null;
  }

  // Increments failure counter and schedules quick or standard subnet scan.
  function noteFailure() {
    failures++;
    scheduleScan(failures >= FAILS_BEFORE_SCAN ? SCAN_SOON_MS : SCAN_PAUSE_MS);
  }

  function subnetOf(address) {
    var match = /^(?:https?:\/\/)?(\d+\.\d+\.\d+)\.\d+(?::\d+)?\/?$/.exec(address || '');
    return match ? match[1] : null;
  }

  // Builds deduplicated list of /24 subnets to scan.
  function scanSubnets(done) {
    var fromServer = subnetOf(server || load('server'));
    function finish(ip) {
      var list = [];
      var own = subnetOf(ip);
      if (own) list.push(own);
      if (fromServer && fromServer !== own) list.push(fromServer);
      if (!list.length) list.push('192.168.1');
      done(list);
    }
    if (!platform.localAddress) return finish(null);
    var answered = false;
    function once(ip) {
      if (answered) return;
      answered = true;
      finish(ip);
    }
    // Timeout guard if localAddress callback does not respond.
    setTimeout(function () { once(null); }, 3000);
    try {
      platform.localAddress(once);
    } catch (e) {
      once(null);
    }
  }

  function probe(address, done) {
    var request = new XMLHttpRequest();
    var finished = false;
    function finish(ok) {
      if (finished) return;
      finished = true;
      done(ok);
    }
    request.onload = function () {
      var body = (request.responseText || '').toLowerCase();
      finish(request.status === 200 && (body.indexOf('gametranslator') >= 0 || body.indexOf('gametrans') >= 0 || body.indexOf('couchsubs') >= 0));
    };
    request.onerror = function () { finish(false); };
    request.ontimeout = function () { finish(false); };
    try {
      request.open('GET', address + '/hello');
      request.timeout = SCAN_TIMEOUT_MS;
      request.send();
    } catch (e) {
      finish(false);
    }
  }

  function scanForServer() {
    if (scanning) return;
    cancelScan();
    scanning = true;
    scanSubnets(function (subnets) {
      var addresses = [];
      for (var s = 0; s < subnets.length; s++) {
        for (var host = 1; host <= 254; host++) addresses.push('http://' + subnets[s] + '.' + host + ':' + SERVER_PORT);
      }
      var next = 0, active = 0, found = false;
      function pump() {
        while (!found && active < SCAN_PARALLEL && next < addresses.length) {
          active++;
          tryAddress(addresses[next++]);
        }
        if (!found && !active && next >= addresses.length) {
          scanning = false;
          scheduleScan();
        }
      }
      function tryAddress(address) {
        probe(address, function (ok) {
          active--;
          if (found) return;
          if (!ok) return pump();
          found = true;
          scanning = false;
          // Persist discovered host address for future launches.
          save('server', address);
          // Reconnect EventSource if server changed or existing stream is closed.
          if (address !== server || (eventSource && eventSource.readyState === 2)) connect(address);
        });
      }
      pump();
    });
  }

  // --- Demo mode ---
  // Cycles sample subtitles when no host is connected so users can preview layout.

  var DEMO_LINES = [
    'ليس لدينا وقت نضيعه هنا.',
    'ميرا: الباب لن يصمد أكثر من ذلك!',
    'ابقَ قريباً. الطريق أمامنا خطير.',
    'انتظر! من أنت؟',
    'هذا الأمر لم ينتهِ بعد.'
  ];
  var DEMO_LINE_MS = 3200;
  var DEMO_GAP_MS = 700;
  var demoTimer = null;
  var demoIndex = 0;

  function demoRunning() { return demoTimer !== null; }

  function nextDemoLine() {
    showSubtitle(DEMO_LINES[demoIndex], DEMO_LINE_MS);
    demoIndex = (demoIndex + 1) % DEMO_LINES.length;
    demoTimer = setTimeout(nextDemoLine, DEMO_LINE_MS + DEMO_GAP_MS);
  }

  function startDemo() {
    if (demoRunning()) return;
    hidePanel();
    $('waiting').className = 'hidden';
    $('demo-badge').className = '';
    demoIndex = 0;
    nextDemoLine();
  }

  function stopDemo() {
    clearTimeout(demoTimer);
    demoTimer = null;
    hideSubtitle('demo');
    $('demo-badge').className = 'hidden';
    // Restore waiting card when not connected to a host.
    if (!server) $('waiting').className = '';
  }

    // Back key dismisses demo or panel first, or exits the app.
  function goBack() {
    if (demoRunning()) return stopDemo();
    if ($('panel').className !== 'hidden') return hidePanel();
    platform.exit();
  }

  // --- Status panel & remote keys ---

  // Formats dot-separated shortcut hints into styled rows.
  function formatKeys() {
    var el = $('keys');
    var parts = el.textContent.split(' · ');
    el.innerHTML = '';
    for (var i = 0; i < parts.length; i++) {
      var colon = parts[i].indexOf(':');
      var row = document.createElement('div');
      row.className = 'key';
      var key = document.createElement('b');
      key.textContent = colon > 0 ? parts[i].slice(0, colon) : '';
      row.appendChild(key);
      row.appendChild(document.createTextNode(colon > 0 ? parts[i].slice(colon + 1).trim() : parts[i]));
      el.appendChild(row);
    }
  }

  // Hide waiting card while status panel is open to prevent overlap.
  function showPanel(autoHide) {
    $('waiting').className = 'hidden';
    $('panel').className = '';
    clearTimeout(panelTimer);
    if (autoHide) panelTimer = setTimeout(hidePanel, 8000);
  }

  function hidePanel() {
    $('panel').className = 'hidden';
    if (!server && !demoRunning()) $('waiting').className = '';
  }

  function togglePanel() {
    if ($('panel').className === 'hidden') showPanel(false); else hidePanel();
  }

  // Cycles HDMI port left/right using directional keys while panel is open.
  function stepHdmi(step) {
    hdmiPort = (hdmiPort + step + 3) % 4 + 1;
    save('hdmi', hdmiPort);
    showHdmi(hdmiPort);
    showPanel(true);
  }

  document.addEventListener('keydown', function (e) {
    var code = e.keyCode;
    if (code === 48) { // 0: clear saved HDMI port and re-detect console
      save('hdmi', '');
      autoSelectConsole(function () {
        setStatus('st-hdmi', hdmiPort + ' (' + t('consoleNotFound') + ')', 'bad');
      });
      showPanel(true);
    } else if (code >= 49 && code <= 52) { // 1-4
      hdmiPort = code - 48;
      save('hdmi', hdmiPort);
      showHdmi(hdmiPort);
      showPanel(true);
    } else if (code === KEY.RED) {
      showSubtitle(t('localTest'), 4000);
    } else if (code === KEY.GREEN) {
      togglePanel();
    } else if (code === KEY.BLUE) {
      if (demoRunning()) stopDemo(); else startDemo();
    } else if (code === KEY.OK && $('waiting').className !== 'hidden') {
      startDemo();
    } else if (code === KEY.OK && !demoRunning()) {
      togglePanel();
    } else if ((code === KEY.LEFT || code === KEY.RIGHT) && $('panel').className !== 'hidden') {
      stepHdmi(code === KEY.RIGHT ? 1 : -1);
    } else if (code === KEY.BACK) {
      goBack();
      e.preventDefault();
    } else if (code === KEY.UP || code === KEY.DOWN) {
      nudgeSubtitle(code === KEY.UP ? 3 : -3);
      e.preventDefault();
    }
  });

  // Handle relaunch parameters when app is brought back to foreground.
  platform.onRelaunch(function (raw) { applyParams(parseParams(raw)); });

  platform.init();
  window.applyI18n();
  formatKeys();
  var savedBottom = load('bottom') || load('appBottom');
  if (savedBottom) setBottom(Number(savedBottom));
  showHdmi(hdmiPort);
  if (!savedPort) autoSelectConsole();

  $('app-version').textContent = APP_VERSION;
  renderDiag();
  var initial = parseParams(platform.launchParams());
  var address = initial.server || load('server') || config.server;
  applyParams(initial);
  if (!server) {
    if (address) connect(address); else $('waiting').className = '';
  }
  if (!server) scanForServer();
  // Keep panel hidden on waiting screen unless toggled by remote.
  if (server) showPanel(true); else hidePanel();
})();

function renderSpeakerText(containerEl, rawText) {
  containerEl.textContent = '';
  const lines = String(rawText || '').split('\n');
  lines.forEach((line, idx) => {
    if (idx > 0) containerEl.appendChild(document.createElement('br'));
    const colonIndex = line.indexOf(':');
    if (colonIndex > 0 && colonIndex < 30) {
      const speakerSpan = document.createElement('span');
      speakerSpan.className = 'speaker-name';
      speakerSpan.textContent = line.slice(0, colonIndex + 1);
      containerEl.appendChild(speakerSpan);
      containerEl.appendChild(document.createTextNode(line.slice(colonIndex + 1)));
    } else {
      containerEl.appendChild(document.createTextNode(line));
    }
  });
}
