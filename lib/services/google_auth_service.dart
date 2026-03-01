import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleOAuthConfig {
  GoogleOAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.scopes,
    required this.clientType,
  });

  final String clientId;
  final String clientSecret;
  final List<String> scopes;
  final String clientType;

  String get normalizedClientId => clientId.trim();

  bool get isDesktopClient => clientType.toLowerCase() == 'desktop';
  String get normalizedClientSecret {
    final normalized = clientSecret.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return '';
    }
    return normalized;
  }

  bool get shouldSendClientSecret => normalizedClientSecret.isNotEmpty;

  bool get isConfigured => normalizedClientId.isNotEmpty;

  factory GoogleOAuthConfig.fromEnvironment() {
    const rawClientId = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID');
    const rawClientSecret =
        String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET');
    const rawScopes = String.fromEnvironment(
      'GOOGLE_OAUTH_SCOPES',
      defaultValue:
          'openid,email,profile,https://www.googleapis.com/auth/youtube.readonly',
    );
    const rawClientType = String.fromEnvironment('GOOGLE_OAUTH_CLIENT_TYPE',
        defaultValue: 'desktop');

    final parsedScopes = rawScopes
        .split(',')
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList();

    return GoogleOAuthConfig(
      clientId: rawClientId,
      clientSecret: rawClientSecret,
      scopes: parsedScopes,
      clientType: rawClientType,
    );
  }
}

class GoogleAuthSession {
  GoogleAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiry,
    required this.scopes,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiry;
  final List<String> scopes;

  bool get isExpired {
    if (expiry == null) {
      return false;
    }
    return DateTime.now().isAfter(expiry!);
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiry': expiry?.toIso8601String(),
        'scopes': scopes,
      };

  factory GoogleAuthSession.fromJson(Map<String, dynamic> json) {
    final parsedScopes = (json['scopes'] as List<dynamic>? ?? const [])
        .map((scope) => scope.toString())
        .toList();

    return GoogleAuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiry: DateTime.tryParse(json['expiry'] as String? ?? ''),
      scopes: parsedScopes,
    );
  }
}

class GoogleAuthService {
  GoogleAuthService(this._config);

  final GoogleOAuthConfig _config;
  final Random _random = Random.secure();

  bool get isConfigured => _config.isConfigured;

  String get diagnosticsSummary {
    return 'type=${_config.clientType}, clientId=${_mask(_config.normalizedClientId)}, secretSet=${_config.normalizedClientSecret.isNotEmpty}, secretLen=${_config.normalizedClientSecret.length}, scopes=${_config.scopes.length}';
  }

  String get setupInstructions {
    return 'Missing GOOGLE_OAUTH_CLIENT_ID. Provide Desktop OAuth values in oauth.env.json and run with --dart-define-from-file.';
  }

  String _mask(String value) {
    if (value.isEmpty) {
      return '<empty>';
    }
    if (value.length <= 10) {
      return '${value.substring(0, 2)}***(${value.length})';
    }
    final start = value.substring(0, 6);
    final end = value.substring(value.length - 6);
    return '$start...$end(${value.length})';
  }

  Future<GoogleAuthSession> signInWithDesktopLoopback() async {
    if (!isConfigured) {
      throw StateError(setupInstructions);
    }

    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      throw StateError(
        'Desktop loopback auth is currently enabled for Windows/Linux/macOS only.',
      );
    }

    final callbackServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse(
      'http://127.0.0.1:${callbackServer.port}/oauth2/callback',
    );

    final state = DateTime.now().millisecondsSinceEpoch.toString();
    final codeVerifier = _randomBase64Url(64);
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);

    final authorizationUrl = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': _config.normalizedClientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'scope': _config.scopes.join(' '),
        'access_type': 'offline',
        'include_granted_scopes': 'true',
        'prompt': 'consent',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    final launched = await launchUrl(
      authorizationUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      await callbackServer.close(force: true);
      throw StateError('Could not open browser for Google authentication.');
    }

    HttpRequest callbackRequest;
    try {
      callbackRequest =
          await callbackServer.first.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      await callbackServer.close(force: true);
      throw StateError('Google login timed out.');
    }

    final params = callbackRequest.uri.queryParameters;
    if (params.containsKey('error')) {
      await _writeCallbackPage(
        callbackRequest,
        success: false,
        message: 'Google sign-in failed: ${params['error']}',
      );
      await callbackServer.close(force: true);
      throw StateError('Google auth failed: ${params['error']}');
    }

    final returnedState = params['state'];
    if (returnedState != state) {
      await _writeCallbackPage(
        callbackRequest,
        success: false,
        message: 'OAuth state mismatch. Please retry sign-in.',
      );
      await callbackServer.close(force: true);
      throw StateError('OAuth state mismatch.');
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      await _writeCallbackPage(
        callbackRequest,
        success: false,
        message: 'OAuth callback missing authorization code.',
      );
      await callbackServer.close(force: true);
      throw StateError('OAuth callback missing authorization code.');
    }

    Map<String, dynamic> tokenJson;
    try {
      tokenJson = await _exchangeAuthorizationCode(
        code: code,
        redirectUri: redirectUri,
        codeVerifier: codeVerifier,
      );
    } on StateError catch (error) {
      await _writeCallbackPage(
        callbackRequest,
        success: false,
        message: error.toString(),
      );
      await callbackServer.close(force: true);
      rethrow;
    }

    await _writeCallbackPage(
      callbackRequest,
      success: true,
      message: 'Google sign-in complete. You can close this tab.',
    );
    await callbackServer.close(force: true);

    final accessToken = tokenJson['access_token'] as String? ?? '';
    if (accessToken.isEmpty) {
      throw StateError('OAuth token exchange did not return access_token.');
    }
    final refreshToken = tokenJson['refresh_token'] as String?;
    final expiresInSeconds = (tokenJson['expires_in'] as num?)?.toInt();
    final expiry = expiresInSeconds == null
        ? null
        : DateTime.now().add(Duration(seconds: expiresInSeconds));
    final scopeString =
        tokenJson['scope'] as String? ?? _config.scopes.join(' ');
    final scopes = scopeString
        .split(RegExp(r'\s+'))
        .where((scope) => scope.isNotEmpty)
        .toList();

    return GoogleAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: expiry,
      scopes: scopes,
    );
  }

  Future<Map<String, dynamic>> _exchangeAuthorizationCode({
    required String code,
    required Uri redirectUri,
    required String codeVerifier,
  }) async {
    final secretsToTry = _config.shouldSendClientSecret
        ? <String?>[_config.normalizedClientSecret]
        : <String?>[null];

    StateError? lastError;

    for (final secret in secretsToTry.toSet()) {
      final body = <String, String>{
        'client_id': _config.normalizedClientId,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri.toString(),
        'code_verifier': codeVerifier,
      };
      if (secret != null && secret.isNotEmpty) {
        body['client_secret'] = secret;
      }

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      Map<String, dynamic> jsonBody = {};
      try {
        jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonBody;
      }

      final errorCode = jsonBody['error'] as String? ?? 'unknown_error';
      final errorDescription =
          jsonBody['error_description'] as String? ?? response.body;

      if (errorCode == 'invalid_client') {
        lastError = StateError(
          'OAuth token exchange failed (invalid_client): Unauthorized. The provided GOOGLE_OAUTH_CLIENT_ID/GOOGLE_OAUTH_CLIENT_SECRET pair was rejected by Google. Verify both values come from the same downloaded Desktop OAuth JSON and rerun with --dart-define-from-file.',
        );
        continue;
      }

      if (errorCode == 'invalid_request' &&
          errorDescription.contains('client_secret is missing')) {
        lastError = StateError(
          'OAuth token exchange failed (invalid_request): client_secret is missing. Add GOOGLE_OAUTH_CLIENT_SECRET from your Desktop OAuth JSON.',
        );
        continue;
      }

      throw StateError(
        'OAuth token exchange failed ($errorCode): $errorDescription',
      );
    }

    throw lastError ??
        StateError(
            'OAuth token exchange failed with unknown authorization error.');
  }

  String _randomBase64Url(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _codeChallengeFromVerifier(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _writeCallbackPage(
    HttpRequest request, {
    required bool success,
    required String message,
  }) async {
    final title = success ? 'SwipeTunes' : 'SwipeTunes - OAuth Error';
    final color = success ? '#0f9d58' : '#d93025';

    request.response
      ..statusCode = success ? 200 : 400
      ..headers.contentType = ContentType.html
      ..write(
        '<html><body style="font-family:Arial, sans-serif; margin:24px;"><h3 style="color:$color;">$title</h3><p>$message</p></body></html>',
      );
    await request.response.close();
  }
}

class GoogleAuthStorage {
  static const String _sessionKey = 'google_auth_session_v1';

  Future<void> saveSession(GoogleAuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<GoogleAuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final session = GoogleAuthSession.fromJson(decoded);
      if (session.accessToken.isEmpty) {
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
