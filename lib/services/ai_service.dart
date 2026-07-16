import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:medisync/env/api.dart';

/// AiService generates short, encouraging health insights via the Claude API.
///
/// Privacy note: only the numeric health values (sleep, steps, date) are sent
/// to Claude — never your WebID, tokens, or anything that identifies you.
class AiService {
  // ===========================================================================
  // ⚠️ HACKATHON ONLY. This API key ships to every browser that loads the web
  // app, so anyone can read it in the network tab and spend on your account.
  // Before/after the hackathon:
  //   1) REVOKE this key at console.anthropic.com → API Keys, and
  //   2) move calls behind a small backend proxy (never expose a key client-side).
  // The key now lives in lib/env/api.dart (git-ignored) — see `apiKey`.
  // ===========================================================================

  static const String _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Current Sonnet model. (The originally-requested
  /// `claude-3-5-sonnet-20241022` was retired in Oct 2025 and now 404s.)
  static const String _model = 'claude-sonnet-5';

  static const int _maxTokens = 150;
  static const Duration _timeout = Duration(seconds: 10);

  /// Build a coaching prompt from health data and ask Claude for one insight.
  Future<String> analyzeHealthData(Map<String, dynamic> data) async {
    final sleep = (data['sleepHours'] ?? '').toString().trim();
    final steps = (data['steps'] ?? '').toString().trim();
    final date =
        (data['timestamp'] ?? data['created'] ?? 'today').toString().trim();

    final prompt = '''
You are a friendly, encouraging health coach. Based on this health data, give ONE personalized insight in 1-2 sentences.
Keep it encouraging and actionable. Be specific to the data.

Data:
- Sleep: ${sleep.isEmpty ? 'not recorded' : '$sleep hours'}
- Steps: ${steps.isEmpty ? 'not recorded' : '$steps steps'}
- Date: $date

Respond with ONLY the insight, no extra text, no markdown, no emojis.''';

    return callClaudeAPI(prompt);
  }

  /// Low-level call to the Claude Messages API.
  ///
  /// The `anthropic-dangerous-direct-browser-access` header is required for the
  /// request to succeed from a browser (Flutter web) — without it the browser
  /// blocks it as a CORS error.
  Future<String> callClaudeAPI(String prompt) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
            'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: jsonEncode({
            'model': _model,
            'max_tokens': _maxTokens,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final content = decoded['content'];
      if (content is List && content.isNotEmpty) {
        final text = content.first['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      throw Exception('Claude returned an empty response');
    }

    throw Exception('Claude API error ${response.statusCode}');
  }
}
