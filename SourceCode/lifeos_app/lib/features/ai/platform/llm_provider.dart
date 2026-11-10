// The user's own AI provider (PBI-027a), behind an interface.
//
// The call goes from this phone to the base URL the user configured, and
// nowhere else: LifeOS has no server in this path. 027b will add a
// managed provider behind the same interface.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/log/app_log.dart';
import '../domain/extraction_contract.dart';

/// Why a call did not produce fields. [message] is the provider's own
/// words, shown to the user as they came (AC5).
class AiFailure implements Exception {
  const AiFailure(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

abstract interface class LlmProvider {
  /// Reads [text] and returns what the model found, or throws
  /// [AiFailure] with the provider's message.
  Future<AiExtraction> extract(String text, {List<String> hints});

  /// One tiny call, for the Test connection button.
  Future<void> testConnection();
}

/// Anything speaking the OpenAI chat-completions API: OpenAI, Groq,
/// DeepSeek, OpenRouter, Mistral, Gemini's compatible endpoint, and a
/// local Ollama or LM Studio.
class OpenAiCompatProvider implements LlmProvider {
  OpenAiCompatProvider({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _client;

  Uri get _endpoint {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    // Accept either the root ("https://api.example.com/v1") or the full
    // path, so a pasted URL works either way.
    final path = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';
    return Uri.parse(path);
  }

  @override
  Future<AiExtraction> extract(String text, {List<String> hints = const []}) async {
    final body = buildExtractionBody(model: model, text: text, hints: hints);
    final reply = await _post(body);
    final parsed = parseExtraction(messageFromResponse(reply));
    if (parsed == null) {
      // A reply we cannot read is not a crash: the caller keeps the
      // on-device result (AC8).
      throw const AiFailure('The AI reply could not be read.');
    }
    return parsed;
  }

  @override
  Future<void> testConnection() async {
    await _post({
      'model': model,
      'max_tokens': 1,
      'messages': [
        {'role': 'user', 'content': 'ping'},
      ],
    });
  }

  Future<String> _post(Map<String, Object?> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              // A local Ollama needs no key; sending an empty one is
              // worse than sending none.
              if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Object catch (e) {
      // Offline, DNS, TLS, timeout: the type only, never the URL or key.
      AppLog.w('ai', 'request failed: ${e.runtimeType}');
      throw AiFailure(_networkMessage(e));
    }
    if (response.statusCode >= 400) {
      final message = _providerMessage(response.body) ?? 'HTTP error';
      AppLog.w('ai', 'provider refused the call');
      throw AiFailure(message, status: response.statusCode);
    }
    return response.body;
  }

  static String _networkMessage(Object e) =>
      e is http.ClientException ? e.message : 'Could not reach the provider.';

  /// The provider's own error text ("quota exceeded"), which is what the
  /// user needs to see — not a message we invented for them.
  static String? _providerMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (error is String) return error;
        if (json['message'] is String) return json['message'] as String;
      }
    } on Object {
      // Not JSON: fall through.
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 300 ? trimmed.substring(0, 300) : trimmed;
  }
}
