import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solid_auth/solid_auth.dart';

import '../models/health_models.dart';

/// SolidService handles real Solid-OIDC authentication and Pod data operations.
///
/// This uses the `solid_auth` package (built on `package:oidc`) to perform a
/// full Authorization Code + PKCE flow against the user's Solid identity
/// provider, and DPoP-signed HTTP requests to read/write data in their Pod.
///
/// Key Concepts:
/// 1. WebID: Your unique identifier in the Solid ecosystem
/// 2. Pod: Your personal data store
/// 3. DPoP: A proof-of-possession token bound to a key pair, signed per request
/// 4. Session: Tokens + key pair persisted in secure storage between launches
class SolidService extends ChangeNotifier {
  // ===========================================================================
  // CONFIG — set [clientIdDocument] to the public HTTPS URL where you host the
  // generated `client-profile.jsonld`. The document's own `client_id` field and
  // its `redirect_uris` must match the values below exactly.
  //
  // Running on web: launch with `flutter run -d chrome --web-port=4400` so the
  // app origin (and therefore the redirect) is http://localhost:4400.
  // ===========================================================================
  // Hosted client-ID document (public gist). The document's own `client_id`
  // field MUST equal this exact URL, and its `redirect_uris` must include
  // [redirectUri] below.
  static const String clientIdDocument =
      'https://gist.githubusercontent.com/Dreams-CCT-Ahlam/47ac335e1a5d56a38a3920dc57657fe2/raw/client-profile.jsonld';
  static const String redirectUri = 'http://localhost:4400/redirect.html';

  /// The high-level Solid-OIDC auth manager. Created once and reused for
  /// session restore, login, DPoP key access, and logout.
  late final SolidAuthManager _auth = SolidAuthManager(
    config: SolidOidcConfig(
      clientId: clientIdDocument,
      redirectUri: Uri.parse(redirectUri),
      postLogoutRedirectUri: Uri.parse(redirectUri),
      scopes: SolidScopes.defaultScopes, // includes `webid` automatically
    ),
  );

  // Current session state
  SolidAuthData? _authData;
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String? get webId => _authData?.webId;
  String? get accessToken => _authData?.accessToken;
  bool get isLoggedIn => _authData != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get profile => _profile;

  /// Restore a previously saved session on app start, if one exists.
  ///
  /// If valid tokens (and the DPoP key pair) are found in secure storage,
  /// the user is silently logged back in.
  Future<void> initializeSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      final restored = await _auth.tryRestoreSession();
      if (restored != null) {
        _authData = restored;
        _buildBasicProfile();
      }
    } catch (e) {
      // Restore is best-effort; failure just means the user must log in.
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Log in with a Solid WebID.
  ///
  /// This resolves the WebID's identity provider, then opens the provider's
  /// login page (browser redirect / popup) where the user authenticates.
  /// There is no password handled inside this app — that happens on the
  /// provider's own page.
  Future<bool> login(String webId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final data = await _auth.authenticate(webId);
      if (data == null) {
        throw Exception('Login was cancelled or failed');
      }

      _authData = data;
      _buildBasicProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log out and clear the persisted session.
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (e) {
      // Even if the remote logout fails, clear local state.
    }
    _authData = null;
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Build a lightweight profile object from the WebID.
  void _buildBasicProfile() {
    final id = _authData?.webId ?? '';
    var name = 'User';
    try {
      final segments = Uri.parse(id).pathSegments;
      if (segments.isNotEmpty && segments.first.isNotEmpty) {
        name = segments.first;
      }
    } catch (_) {
      // Keep default name.
    }
    _profile = {'webId': id, 'name': name};
  }

  /// The Pod root derived from the WebID.
  ///
  /// e.g. https://pods.d01.solidcommunity.au/ahlam/profile/card#me
  ///   -> https://pods.d01.solidcommunity.au/ahlam/
  String get _podRoot {
    final id = _authData!.webId;
    final base = id.split('/profile/').first;
    return base.endsWith('/') ? base : '$base/';
  }

  /// Normalize a file name to its base (without a trailing `.ttl`).
  ///
  /// [listHealthData] returns names ending in `.ttl`, while [writeHealthData]
  /// takes a bare name — this lets read/delete accept either form.
  String _fileBase(String fileName) =>
      fileName.endsWith('.ttl') ? fileName.substring(0, fileName.length - 4) : fileName;

  /// Perform a DPoP-signed HTTP request against a Pod resource.
  ///
  /// A fresh DPoP proof is generated for every request (as required by the
  /// Solid OP) and signed by the same key pair bound to the access token.
  Future<http.Response> _request(
    String method,
    String url, {
    String? body,
    Map<String, String>? extraHeaders,
  }) async {
    final data = _authData;
    if (data == null) {
      throw Exception('Not authenticated');
    }

    final dpop = await DpopTokenGenerator.generateForRequest(
      endpointUrl: url,
      httpMethod: method,
      accessToken: data.accessToken,
      keyManager: _auth.keyManager,
    );

    final headers = <String, String>{
      'Authorization': 'DPoP ${data.accessToken}',
      'DPoP': dpop,
      if (extraHeaders != null) ...extraHeaders,
    };

    final uri = Uri.parse(url);
    const timeout = Duration(seconds: 15);

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers).timeout(timeout);
      case 'PUT':
        return http.put(uri, headers: headers, body: body).timeout(timeout);
      case 'POST':
        return http.post(uri, headers: headers, body: body).timeout(timeout);
      case 'DELETE':
        return http.delete(uri, headers: headers).timeout(timeout);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  /// Create the `medi-sync` container in the Pod if it doesn't exist.
  Future<bool> createMediSyncContainer() async {
    try {
      final containerUrl = '${_podRoot}medi-sync/';

      final response = await _request(
        'PUT',
        containerUrl,
        extraHeaders: {
          'Content-Type': 'text/turtle',
          'Link': '<http://www.w3.org/ns/ldp#BasicContainer>; rel="type"',
        },
        body: '''
@prefix ldp: <http://www.w3.org/ns/ldp#> .
@prefix dcterms: <http://purl.org/dc/terms/> .

<> a ldp:BasicContainer ;
    dcterms:title "MediSync Health Data" ;
    dcterms:description "Personal health data for MediSync application" .
''',
      );

      // 201 created, 200/204 already exists / updated, 205 reset.
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      _errorMessage = 'Failed to create container: $e';
      notifyListeners();
      return false;
    }
  }

  /// Write health data to the Pod as a Turtle (RDF) file.
  Future<bool> writeHealthData(String fileName, Map<String, dynamic> data) async {
    try {
      final fileUrl = '${_podRoot}medi-sync/$fileName.ttl';
      final turtleData = _convertToTurtle(data);

      final response = await _request(
        'PUT',
        fileUrl,
        extraHeaders: {'Content-Type': 'text/turtle'},
        body: turtleData,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      _errorMessage = 'Failed to write health data: $e';
      notifyListeners();
      return false;
    }
  }

  /// Read a health data file from the Pod.
  ///
  /// Also returns the raw Turtle body under the `_raw` key so callers can show
  /// the exact stored representation.
  Future<Map<String, dynamic>?> readHealthData(String fileName) async {
    try {
      final fileUrl = '${_podRoot}medi-sync/${_fileBase(fileName)}.ttl';
      final response = await _request(
        'GET',
        fileUrl,
        extraHeaders: {'Accept': 'text/turtle'},
      );

      if (response.statusCode == 200) {
        final parsed = _parseTurtle(response.body);
        parsed['_raw'] = response.body;
        return parsed;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to read health data: $e';
      notifyListeners();
      return null;
    }
  }

  /// Delete a health data file from the Pod.
  Future<bool> deleteHealthData(String fileName) async {
    try {
      final fileUrl = '${_podRoot}medi-sync/${_fileBase(fileName)}.ttl';
      final response = await _request('DELETE', fileUrl);

      // 200 OK, 204 No Content, 205 Reset — all indicate success.
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        throw Exception('Server returned ${response.statusCode}');
      }
      // Drop any cached insight for the deleted file.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('insight_$fileName');
      await prefs.remove('insight_${_fileBase(fileName)}.ttl');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete health data: $e';
      notifyListeners();
      return false;
    }
  }

  // ── AI insight caching (shared_preferences) ────────────────────────────────

  /// Return a cached insight for [fileName], or null if none exists.
  ///
  /// Shape: `{ "insight": "...", "timestamp": "2026-07-14T..." }`.
  Future<Map<String, dynamic>?> getCachedInsight(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('insight_$fileName');
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persist an insight for [fileName] with its generation [timestamp].
  Future<void> cacheInsight(
      String fileName, String insight, String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'insight_$fileName',
      jsonEncode({'insight': insight, 'timestamp': timestamp}),
    );
  }

  /// List all `.ttl` files in the `medi-sync` container.
  Future<List<String>> listHealthData() async {
    try {
      final containerUrl = '${_podRoot}medi-sync/';
      final response = await _request(
        'GET',
        containerUrl,
        extraHeaders: {'Accept': 'application/ld+json'},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);
      final files = <String>[];

      // JSON-LD container listings may be a bare list or an object with @graph.
      final items = decoded is List
          ? decoded
          : (decoded is Map && decoded['@graph'] is List
              ? decoded['@graph'] as List
              : const []);

      final seen = <String>{};
      for (final item in items) {
        if (item is Map && item['@id'] != null) {
          final id = item['@id'] as String;
          if (id.endsWith('.ttl')) {
            final name = id.split('/').last;
            // A container listing can reference the same resource via more
            // than one node, so de-duplicate by file name.
            if (seen.add(name)) {
              files.add(name);
            }
          }
        }
      }

      return files;
    } catch (e) {
      _errorMessage = 'Failed to list health data: $e';
      notifyListeners();
      return [];
    }
  }

  // ── Charts & health score ───────────────────────────────────────────────

  /// Read every health file, group entries by calendar day, average the
  /// metrics per day, and return the most recent [days] days ascending.
  ///
  /// Days with only partial data are kept — a missing metric comes back as
  /// null so charts can skip it gracefully.
  Future<List<HealthPoint>> parseHealthDataForCharts({int days = 7}) async {
    final files = await listHealthData();
    if (files.isEmpty) return [];

    // Read all files concurrently; a null result just means we skip that file.
    final results = await Future.wait(files.map(readHealthData));

    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    for (final data in results) {
      if (data == null) continue;
      final date = _extractDate(data);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      byDay.putIfAbsent(day, () => []).add(data);
    }

    final points = <HealthPoint>[];
    byDay.forEach((day, entries) {
      final sleeps = <double>[];
      final stepsList = <int>[];
      for (final e in entries) {
        final s = double.tryParse((e['sleepHours'] ?? '').toString().trim());
        if (s != null) sleeps.add(s);
        final st = int.tryParse(
            (e['steps'] ?? '').toString().trim().replaceAll(',', ''));
        if (st != null) stepsList.add(st);
      }
      points.add(HealthPoint(
        date: day,
        sleepHours: sleeps.isEmpty
            ? null
            : sleeps.reduce((a, b) => a + b) / sleeps.length,
        steps: stepsList.isEmpty
            ? null
            : (stepsList.reduce((a, b) => a + b) / stepsList.length).round(),
      ));
    });

    points.sort((a, b) => a.date.compareTo(b.date));
    if (points.length > days) {
      return points.sublist(points.length - days);
    }
    return points;
  }

  /// Compute an overall 0–100 health score from a series of daily points.
  ///
  /// * Sleep score:       average hours / 8 × 100 (capped at 100)
  /// * Steps score:       average steps / 10000 × 100 (capped at 100)
  /// * Consistency score: days with data / 7 × 100 (capped at 100)
  /// * Overall:           mean of the three
  HealthScore calculateHealthScore(List<HealthPoint> points) {
    final sleeps =
        points.where((p) => p.sleepHours != null).map((p) => p.sleepHours!);
    final steps = points.where((p) => p.steps != null).map((p) => p.steps!);

    final avgSleep = sleeps.isEmpty
        ? 0.0
        : sleeps.reduce((a, b) => a + b) / sleeps.length;
    final avgSteps = steps.isEmpty
        ? 0.0
        : steps.reduce((a, b) => a + b) / steps.length;

    final sleepScore = (avgSleep / 8 * 100).clamp(0.0, 100.0).toDouble();
    final stepsScore = (avgSteps / 10000 * 100).clamp(0.0, 100.0).toDouble();
    final consistencyScore =
        (points.length / 7 * 100).clamp(0.0, 100.0).toDouble();

    return HealthScore(
      sleepScore: sleepScore,
      stepsScore: stepsScore,
      consistencyScore: consistencyScore,
      trend: _computeTrend(points),
    );
  }

  /// Compare the first half of the window against the second half to decide
  /// whether the user's combined sleep+steps metric is trending up or down.
  HealthTrend _computeTrend(List<HealthPoint> points) {
    if (points.length < 2) return HealthTrend.stable;

    double normalized(HealthPoint p) {
      final s = ((p.sleepHours ?? 0) / 8).clamp(0.0, 1.0).toDouble();
      final st = ((p.steps ?? 0) / 10000).clamp(0.0, 1.0).toDouble();
      return (s + st) / 2;
    }

    final mid = points.length ~/ 2;
    final firstHalf = points.sublist(0, mid);
    final secondHalf = points.sublist(mid);
    if (firstHalf.isEmpty || secondHalf.isEmpty) return HealthTrend.stable;

    final a =
        firstHalf.map(normalized).reduce((x, y) => x + y) / firstHalf.length;
    final b =
        secondHalf.map(normalized).reduce((x, y) => x + y) / secondHalf.length;
    final diff = b - a;

    if (diff > 0.05) return HealthTrend.improving;
    if (diff < -0.05) return HealthTrend.declining;
    return HealthTrend.stable;
  }

  /// Best-effort extraction of a date from a parsed health record.
  ///
  /// Prefers the explicit `timestamp`/`date` value, then falls back to the
  /// `dcterms:created` triple embedded in the raw Turtle body.
  DateTime? _extractDate(Map<String, dynamic> data) {
    final explicit =
        (data['timestamp'] ?? data['date'] ?? data['created'])?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      final parsed = DateTime.tryParse(explicit);
      if (parsed != null) return parsed;
    }

    final raw = data['_raw']?.toString() ?? '';
    final match = RegExp(r'dcterms:created\s+"([^"]+)"').firstMatch(raw);
    if (match != null) {
      final parsed = DateTime.tryParse(match.group(1)!);
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Convert a Dart map to Turtle RDF format.
  String _convertToTurtle(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('@prefix ex: <http://example.org/medisync/> .');
    buffer.writeln('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .');
    buffer.writeln('@prefix dcterms: <http://purl.org/dc/terms/> .');
    buffer.writeln();
    buffer.writeln('<> a ex:HealthData ;');

    data.forEach((key, value) {
      if (value is String) {
        buffer.writeln('    ex:$key "$value" ;');
      } else if (value is num || value is bool) {
        buffer.writeln('    ex:$key $value ;');
      }
    });

    buffer.writeln(
        '    dcterms:created "${DateTime.now().toIso8601String()}"^^xsd:dateTime .');

    return buffer.toString();
  }

  /// Parse Turtle RDF data (simplified).
  Map<String, dynamic> _parseTurtle(String turtleData) {
    final data = <String, dynamic>{};

    for (final line in turtleData.split('\n')) {
      if (line.contains('ex:') && line.contains('"')) {
        final parts = line.split('ex:');
        if (parts.length > 1) {
          final keyValue = parts[1].split('"');
          if (keyValue.length > 1) {
            final key = keyValue[0].trim().replaceAll(' ', '');
            data[key] = keyValue[1];
          }
        }
      }
    }

    return data;
  }
}
