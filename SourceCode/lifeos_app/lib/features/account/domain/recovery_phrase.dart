// Recovery phrase generation and verification (PBI-026a).
import 'dart:convert';
import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as crypto;

/// Generates and manages recovery phrases.
class RecoveryPhrase {
  RecoveryPhrase._(this._mnemonic);

  final String _mnemonic;

  /// Generate a new 12-word recovery phrase.
  factory RecoveryPhrase.generate() {
    final mnemonic = bip39.generateMnemonic(strength: 128); // 12 words
    return RecoveryPhrase._(mnemonic);
  }

  /// Create from existing phrase.
  factory RecoveryPhrase.fromPhrase(String phrase) {
    final normalized = phrase.trim().toLowerCase();
    if (!bip39.validateMnemonic(normalized)) {
      throw ArgumentError('Invalid recovery phrase');
    }
    return RecoveryPhrase._(normalized);
  }

  /// Try to parse a phrase, returns null if invalid.
  static RecoveryPhrase? parse(String phrase) {
    try {
      return RecoveryPhrase.fromPhrase(phrase);
    } catch (_) {
      return null;
    }
  }

  /// The 12 words.
  List<String> get words => _mnemonic.split(' ');

  /// The full phrase as a string.
  String toPhrase() => _mnemonic;

  /// SHA-256 hash of the phrase (for verification, stored in DB).
  String toHash() {
    final bytes = utf8.encode(_mnemonic);
    return crypto.sha256.convert(bytes).toString();
  }

  /// Verify that a phrase matches a stored hash.
  static bool verify(String phrase, String storedHash) {
    try {
      final recovery = RecoveryPhrase.fromPhrase(phrase);
      return recovery.toHash() == storedHash;
    } catch (_) {
      return false;
    }
  }

  /// Get random word indices for verification (e.g., "Enter word 3, 7, 11").
  static List<int> getVerificationIndices() {
    final random = Random();
    final indices = <int>{};
    while (indices.length < 3) {
      indices.add(random.nextInt(12));
    }
    return indices.toList()..sort();
  }
}
