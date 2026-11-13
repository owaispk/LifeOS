// When cloud AI may run at all (PBI-027a) — pure Dart.
//
// Every condition is checked in one place so the answer is a single
// testable function: there is no second path to a network call.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../capture/ocr/doc_classifier.dart' show Classification;

/// What the user said when asked to send a document's text.
enum AiConsent {
  /// Ask each time (the default).
  ask,

  /// Send without asking again.
  always,

  /// Never send anything until this is changed in Settings (AC7).
  never;

  static AiConsent parse(String? s) =>
      AiConsent.values.asNameMap()[s] ?? AiConsent.ask;
}

/// Everything the gate needs to decide.
class AiGateInput {
  const AiGateInput({
    required this.classification,
    required this.premium,
    required this.configured,
    required this.consent,
    this.hasText = true,
  });

  final Classification classification;

  /// PBI-029's entitlement.
  final bool premium;

  /// A base URL, model and key are all present.
  final bool configured;
  final AiConsent consent;

  /// An unreadable document has nothing to send.
  final bool hasText;
}

/// Why the AI did not run — the UI shows a different thing for each.
enum AiGate {
  /// On-device was sure enough. No call, for any tier (AC1).
  confident,

  /// Nothing was read, so there is nothing to send.
  noText,

  /// Free tier: the inline teaser may be offered (AC4).
  notPremium,

  /// Premium but no provider set up: behaves exactly like free (AC5).
  notConfigured,

  /// The user said never (AC7).
  refused,

  /// Ask before sending.
  ask,

  /// Consent already given — send.
  send,
}

/// The single decision point for cloud AI.
AiGate aiGate(AiGateInput input) {
  // Order matters: a confident read never reaches the network, whatever
  // the user has configured or consented to.
  if (!input.hasText) return AiGate.noText;
  if (input.classification.isConfident) return AiGate.confident;
  if (!input.premium) return AiGate.notPremium;
  if (!input.configured) return AiGate.notConfigured;
  return switch (input.consent) {
    AiConsent.never => AiGate.refused,
    AiConsent.ask => AiGate.ask,
    AiConsent.always => AiGate.send,
  };
}

/// Whether this gate result means a call may be made now.
bool gateAllowsCall(AiGate gate) => gate == AiGate.send;

/// The key a result is cached under: the document's text, not its image
/// and not its id, so re-scanning the same paper is free (AC3).
String textHash(String text) =>
    sha256.convert(utf8.encode(text.trim())).toString();

// ── AI task types (PBI-039a) ──

/// Different AI features that may have separate consent settings.
enum AiTaskType {
  /// Document extraction (PBI-027a).
  extraction,

  /// Daily Voice Brief (PBI-039a).
  brief,
}

/// Gate for brief AI calls — simpler than document extraction.
AiGate briefAiGate({
  required bool premium,
  required bool configured,
  required AiConsent consent,
}) {
  if (!premium) return AiGate.notPremium;
  if (!configured) return AiGate.notConfigured;
  return switch (consent) {
    AiConsent.never => AiGate.refused,
    AiConsent.ask => AiGate.ask,
    AiConsent.always => AiGate.send,
  };
}
