// Managed AI (PBI-027b): LifeOS's own key pays for the call, so the key
// lives server-side and the phone talks to a thin proxy instead.
//
// The proxy is stateless — it checks the store's proof of purchase,
// counts the call against a daily cap, forwards the text and returns the
// JSON. It keeps nothing. Its source is in `server/ai-proxy/`.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/log/app_log.dart';
import '../domain/extraction_contract.dart';
import 'llm_provider.dart';

/// Where the managed proxy lives. Overridable at build time so a staging
/// deployment can be pointed at without touching the source:
/// `--dart-define=LIFEOS_AI_PROXY=https://…`.
const managedProxyUrl = String.fromEnvironment(
  'LIFEOS_AI_PROXY',
  defaultValue: 'https://ai.lifeos.app/extract',
);

/// Sent so the proxy can refuse a client whose prompt it no longer
/// matches, without an app release.
const managedClientVersion = 1;

class ManagedProvider implements LlmProvider {
  ManagedProvider({
    required this.entitlementToken,
    String? url,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : url = url ?? managedProxyUrl,
       _client = client ?? http.Client();

  /// The store's purchase token. The proxy checks it with the store;
  /// LifeOS has no account system to check instead.
  final String entitlementToken;
  final String url;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<AiExtraction> extract(String text, {List<String> hints = const []}) async {
    final reply = await _post({
      'text': text.length > maxTextChars
          ? text.substring(0, maxTextChars)
          : text,
      if (hints.isNotEmpty) 'hints': hints,
      'client': managedClientVersion,
    });
    // The proxy returns the same strict JSON shape a provider would, so
    // the 027a parser — and all its hardening — is reused unchanged.
    final parsed = parseExtraction(reply);
    if (parsed == null) {
      throw const AiFailure('The AI reply could not be read.');
    }
    return parsed;
  }

  @override
  Future<void> testConnection() async {
    await _post({'text': 'ping', 'client': managedClientVersion});
  }

  Future<String> _post(Map<String, Object?> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $entitlementToken',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Object catch (e) {
      AppLog.w('ai', 'managed request failed: ${e.runtimeType}');
      throw const AiFailure('Could not reach LifeOS AI.');
    }
    if (response.statusCode >= 400) {
      AppLog.w('ai', 'managed call refused');
      throw AiFailure(
        managedErrorMessage(response.statusCode, response.body),
        status: response.statusCode,
      );
    }
    return response.body;
  }
}

/// What the user is told when the proxy says no. Pure, so the wording
/// for each case is testable (AC2).
///
/// These are LifeOS's own words rather than a provider's, because the
/// proxy is ours: "quota exceeded" from a shared key would be meaningless
/// to the person holding the phone.
String managedErrorMessage(int status, String body) => switch (status) {
  // The store says this phone is not premium (any more).
  401 || 403 => 'Premium is needed for LifeOS AI.',
  // Daily cap, or the global kill switch.
  429 => 'LifeOS AI has had a lot of use today. Try again tomorrow.',
  503 => 'LifeOS AI is off right now.',
  _ => 'LifeOS AI could not read this document.',
};
