// SPDX-License-Identifier: AGPL-3.0-only
// Retrieves the account ID required for Remote Play registration via PSN sign-in.
// Stream and client metadata aligned with chiaki-ng and PsnAccount.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _oauthHost = 'https://ca.account.sony.com/api/authz/v3/oauth';
const _redirectUri = 'com.playstation.PlayStationApp://redirect';
const _clientId = '09515159-7237-4370-9b40-3806e674c883';
const _scope = 'psn:clientapp';
const _userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';
const _clientVersion = '24.7.0';
const _platform = 'Android';
const _npClientId = 'ba495a24-818c-472b-b169-199ab4fa9a75';
const _npClientSecret = '9d8d16f2-6d3c-4f13-8673-6a622e739666';

class PsnException implements Exception {
  const PsnException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PsnAccount {
  /// Sony sign-in URL opened in the in-app browser.
  static Uri get authorizeUrl => Uri.parse(_oauthHost).replace(queryParameters: const {
        'response_type': 'code',
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'scope': _scope,
        'access_type': 'offline',
        'service_entity': 'urn:service-entity:psn',
        'ui': 'pr',
        'elements': 'all',
        'prompt': 'login',
      });

  static bool isRedirect(String url) => url.startsWith(_redirectUri) || Uri.tryParse(url)?.scheme == 'com.playstation.playstationapp';

  /// One-time authorization code extracted from the redirect URL after sign-in.
  static String? codeFromRedirect(String url) => Uri.tryParse(url)?.queryParameters['code'];

  /// Error parameter from redirect URL if sign-in did not complete, or null.
  static String? errorFromRedirect(String url) {
    final uri = Uri.tryParse(url);
    final error = uri?.queryParameters['error'];
    if (error == null || error.isEmpty) return null;
    final desc = uri?.queryParameters['error_description'];
    return desc != null && desc.isNotEmpty ? '$error: $desc' : error;
  }

  /// Exchanges the code for a token and resolves the 8-byte account ID without storing the token.
  static Future<Uint8List> accountId(String code) async {
    final tokenResponse = await _postToken(code);
    final accessToken = tokenResponse['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw PsnException('لم يتم استلام رمز الوصول من Sony${_sonyError(tokenResponse)}');
    }

    final userId = await _fetchUserId(accessToken);
    return accountIdFromDecimal(userId);
  }

  static Future<Map<String, dynamic>> _postToken(String code) async {
    final basicAuth = 'Basic ${base64Encode(utf8.encode('$_npClientId:$_npClientSecret'))}';
    final http.Response token;
    try {
      token = await http.post(
        Uri.parse('$_oauthHost/token'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'User-Agent': _userAgent,
          'X-PSN-APP-VER': _clientVersion,
          'X-PSN-PLATFORM': _platform,
          'X-PSN-CLIENT-ID': _npClientId,
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'token_format': 'jwt',
        },
      );
    } catch (error) {
      throw PsnException('تعذر الاتصال بـ Sony: $error');
    }

    final tokenJson = _decodeObject(token.body);
    if (token.statusCode != 200) {
      throw PsnException('رفضت Sony تسجيل الدخول (HTTP ${token.statusCode})${_sonyError(tokenJson)}');
    }
    return tokenJson;
  }

  static Future<String> _fetchUserId(String accessToken) async {
    final http.Response info;
    try {
      info = await http.get(
        Uri.parse('https://authz.np.playstation.com/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'User-Agent': _userAgent,
        },
      );
    } catch (error) {
      throw PsnException('تعذر الاتصال بـ Sony: $error');
    }

    final infoJson = _decodeObject(info.body);
    if (info.statusCode != 200) {
      throw PsnException('تعذر الحصول على معرّف الحساب (HTTP ${info.statusCode})${_sonyError(infoJson)}');
    }
    final userId = (infoJson['userId'] ?? infoJson['account_id'])?.toString().trim();
    if (userId == null || userId.isEmpty) {
      throw const PsnException('لم يُعثر على معرّف المستخدم في استجابة Sony.');
    }
    return userId;
  }

  /// Converts decimal `user_id` into an 8-byte little-endian byte list.
  static Uint8List accountIdFromDecimal(String userId) {
    final value = BigInt.tryParse(userId.trim());
    if (value == null || value <= BigInt.zero || value >= (BigInt.one << 64)) {
      throw const PsnException('معرّف حساب PSN غير صالح.');
    }
    final bytes = Uint8List(8);
    var current = value;
    for (var i = 0; i < 8; i++) {
      bytes[i] = (current & BigInt.from(0xff)).toInt();
      current = current >> 8;
    }
    return bytes;
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
      return const {};
    } on FormatException {
      return const {};
    }
  }

  /// Preserves characters allowed by Sony's expected error format (including ':' and '/').
  static String _sonyError(Map<String, dynamic> json) {
    final err = (json['error'] ?? json['error_code'])?.toString().trim();
    final desc = json['error_description']?.toString().trim();
    if (err == null || err.isEmpty) return '';
    return desc != null && desc.isNotEmpty ? ' ($err: $desc)' : ' ($err)';
  }
}
