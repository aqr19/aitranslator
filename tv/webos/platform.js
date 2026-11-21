// SPDX-License-Identifier: AGPL-3.0-only
// webOS-specific platform bridge (Tizen counterpart: tv/tizen/platform.js).
(function () {
  'use strict';

  window.GAMETRANSLATOR_PLATFORM = window.GAMETRANSLATOR_PLATFORM = {
    backKey: 461,

    // Gameplay uses the game controller while the TV remote stays idle; the TV may otherwise enter screensaver/sleep.
    // Before activating the screensaver, webOS sends a timestamped request to subscribers; ack:false defers it
    // if the service/permission is available; otherwise fail silently.
    init: function () {
      var CLIENT = 'com.gametranslator.tv';
      try {
        var register = new PalmServiceBridge();
        register.onservicecallback = function (message) {
          var request;
          try { request = JSON.parse(message); } catch (e) { return; }
          if (!request) return;
          // Diagnostic summary for the status panel: permission reason or deferred count.
          if (request.returnValue === false) window.__screenSaverStatus = 'denied: ' + (request.errorText || request.errorCode);
          if (request.timestamp === undefined) return;
          window.__screenSaverCount = (window.__screenSaverCount || 0) + 1;
          window.__screenSaverStatus = 'deferred ' + window.__screenSaverCount;
          var reply = new PalmServiceBridge();
          reply.call('luna://com.webos.service.tvpower/power/responseScreenSaverRequest',
            JSON.stringify({ clientName: CLIENT, ack: false, timestamp: request.timestamp }));
          window.__screenSaverReply = reply;
        };
        register.call('luna://com.webos.service.tvpower/power/registerScreenSaverRequest',
          JSON.stringify({ subscribe: true, clientName: CLIENT }));
        // Keep subscription handle alive for the lifetime of the app.
        window.__screenSaverBridge = register;
      } catch (e) {}
    },

    launchParams: function () {
      return window.PalmSystem && window.PalmSystem.launchParams;
    },

    onRelaunch: function (callback) {
      document.addEventListener('webOSRelaunch', function (e) { callback(e.detail); });
    },

    // onStatus: 'loading' | 'ready' | 'playing' | 'inputError' | 'sourceError'
    showHdmi: function (port, host, onStatus) {
      host.innerHTML = '';

      var video = document.createElement('video');
      video.autoplay = true;
      var source = document.createElement('source');
      source.setAttribute('type', 'service/webos-external');
      source.setAttribute('src', 'ext://hdmi:' + port);
      video.appendChild(source);

      onStatus('loading');
      video.addEventListener('loadeddata', function () { onStatus('ready'); });
      video.addEventListener('playing', function () { onStatus('playing'); });
      video.addEventListener('error', function () { onStatus('inputError'); });
      source.addEventListener('error', function () { onStatus('sourceError'); });

      host.appendChild(video);
    },

    // Finds the HDMI input port connected to the game console from the TV input list.
    // Invokes callback with null if no matching input is found.
    findConsolePort: function (callback) {
      var done = false;
      function finish(port, label) {
        if (done) return;
        done = true;
        callback(port, label);
      }
      try {
        var bridge = new PalmServiceBridge();
        bridge.onservicecallback = function (msg) {
          var devices;
          try { devices = JSON.parse(msg).devices || []; } catch (e) { return finish(null); }
          var hdmi = devices.filter(function (d) { return /^HDMI_/.test(d.id); });
          // Inactive inputs may still carry a label when in rest mode; prefer active ones.
          var consoles = hdmi.filter(function (d) {
            return d.spdSourceDeviceInfo === 'GAME' || /playstation|ps5/i.test((d.label || '') + ' ' + (d.spdProductDescription || ''));
          });
          var pick = consoles.filter(function (d) { return d.activate; })[0] || consoles[0] ||
            hdmi.filter(function (d) { return d.activate; })[0];
          finish(pick ? pick.port : null, pick ? pick.label : null);
        };
        bridge.call('luna://com.webos.service.eim/getAllInputStatus', '{}');
        // Retain request reference until callback completes.
        window.__eimBridge = bridge;
        setTimeout(function () { finish(null); }, 3000);
      } catch (e) {
        finish(null);
      }
    },

    localAddress: function (callback) {
      var done = false;
      function finish(ip) {
        if (done) return;
        done = true;
        callback(ip);
      }
      try {
        var bridge = new PalmServiceBridge();
        bridge.onservicecallback = function (msg) {
          try {
            var res = JSON.parse(msg) || {};
            var ip = (res.wired && res.wired.ipAddress) || (res.wifi && res.wifi.ipAddress);
            if (ip && /^\d+\.\d+\.\d+\.\d+$/.test(ip)) return finish(ip);
          } catch (e) {}
          finish(null);
        };
        bridge.call('luna://com.palm.connectionmanager/getStatus', '{}');
        window.__netBridge = bridge;
        setTimeout(function () { finish(null); }, 2000);
      } catch (e) {
        finish(null);
      }
    },

    // Local IPv4 address of the TV (preferring wired), or null if unavailable.
    localAddress: function (callback) {
      var done = false;
      function finish(ip) {
        if (done) return;
        done = true;
        callback(ip || null);
      }
      try {
        var bridge = new PalmServiceBridge();
        bridge.onservicecallback = function (msg) {
          var status;
          try { status = JSON.parse(msg) || {}; } catch (e) { return finish(null); }
          var wired = status.wired || {};
          var wifi = status.wifi || {};
          if (wired.state === 'connected' && wired.ipAddress) return finish(wired.ipAddress);
          if (wifi.state === 'connected' && wifi.ipAddress) return finish(wifi.ipAddress);
          finish(wired.ipAddress || wifi.ipAddress || null);
        };
        bridge.call('luna://com.webos.service.connectionmanager/getStatus', '{}');
        // Retain request reference until callback completes.
        window.__netBridge = bridge;
        setTimeout(function () { finish(null); }, 2000);
      } catch (e) {
        finish(null);
      }
    },

    exit: function () {
      if (window.PalmSystem && window.PalmSystem.platformBack) window.PalmSystem.platformBack();
    }
  };
})();
