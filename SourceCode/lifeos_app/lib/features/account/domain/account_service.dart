import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/ids.dart';
import '../../../data/db/app_database.dart';
import 'recovery_phrase.dart';

/// Stored account data from the accounts table.
class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.recoveryPhraseHash,
    required this.createdAt,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String recoveryPhraseHash;
  final int createdAt;
  final bool isActive;

  factory Account.fromRow(AccountRow row) => Account(
    id: row.id,
    userId: row.userId,
    recoveryPhraseHash: row.recoveryPhraseHash,
    createdAt: row.createdAt,
    isActive: row.isActive,
  );
}

/// Service for account and recovery phrase operations.
///
/// The recovery phrase itself is never stored. We only store:
/// - A SHA-256 hash of the phrase for verification during recovery
/// - The master key derived from the phrase (in secure storage)
class AccountService {
  AccountService(this._db, this._idGen);

  final AppDatabase _db;
  final IdGenerator _idGen;

  static const _storage = FlutterSecureStorage();
  static const _derivedKeyName = 'lifeos.derived_master_key.v1';
  static const _phraseHashName = 'lifeos.phrase_hash.v1';

  /// Gets the current active account, if any.
  Future<Account?> getActiveAccount() async {
    final rows = await (_db.select(_db.accounts)
          ..where((t) => t.isActive.equals(true)))
        .get();
    return rows.isEmpty ? null : Account.fromRow(rows.first);
  }

  /// Checks if an account exists.
  Future<bool> hasAccount() async {
    final account = await getActiveAccount();
    return account != null;
  }

  /// Creates a new account with the given recovery phrase.
  ///
  /// The phrase is used to derive a master key, then only the phrase hash
  /// and derived key are stored — the phrase itself is never persisted.
  ///
  /// Returns the created account.
  Future<Account> createAccount({
    required RecoveryPhrase phrase,
    required String userId,
  }) async {
    // Derive master key from phrase.
    final masterKey = await deriveMasterKey(phrase);

    // Store the derived master key in secure storage.
    await _storage.write(key: _derivedKeyName, value: base64Encode(masterKey));

    // Store phrase hash in secure storage for quick verification.
    final phraseHash = phrase.toHash();
    await _storage.write(key: _phraseHashName, value: phraseHash);

    // Create account record.
    final id = _idGen.next();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.accounts).insert(
      AccountsCompanion.insert(
        id: id,
        userId: userId,
        recoveryPhraseHash: phraseHash,
        createdAt: now,
      ),
    );

    return Account(
      id: id,
      userId: userId,
      recoveryPhraseHash: phraseHash,
      createdAt: now,
      isActive: true,
    );
  }

  /// Verifies a recovery phrase against the stored hash.
  Future<bool> verifyPhrase(RecoveryPhrase phrase) async {
    final stored = await _storage.read(key: _phraseHashName);
    if (stored == null) return false;
    return phrase.toHash() == stored;
  }

  /// Recovers an account using the recovery phrase.
  ///
  /// Verifies the phrase against the stored hash, then re-derives and
  /// stores the master key.
  ///
  /// Returns true if recovery succeeded.
  Future<bool> recoverAccount(RecoveryPhrase phrase) async {
    // Find the account with this phrase hash.
    final phraseHash = phrase.toHash();
    final rows = await (_db.select(_db.accounts)
          ..where((t) => t.recoveryPhraseHash.equals(phraseHash)))
        .get();

    if (rows.isEmpty) return false;

    // Re-derive and store the master key.
    final masterKey = await deriveMasterKey(phrase);
    await _storage.write(key: _derivedKeyName, value: base64Encode(masterKey));
    await _storage.write(key: _phraseHashName, value: phraseHash);

    // Mark this account as active, deactivate others.
    await (_db.update(_db.accounts)..where((t) => t.isActive.equals(true)))
        .write(const AccountsCompanion(isActive: drift.Value(false)));
    await (_db.update(_db.accounts)
          ..where((t) => t.recoveryPhraseHash.equals(phraseHash)))
        .write(const AccountsCompanion(isActive: drift.Value(true)));

    return true;
  }

  /// Gets the derived master key from secure storage.
  ///
  /// Returns null if no account exists or the key isn't stored.
  Future<Uint8List?> getDerivedMasterKey() async {
    final encoded = await _storage.read(key: _derivedKeyName);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Clears the stored derived key and phrase hash (for "delete all data").
  Future<void> clearStoredKeys() async {
    await _storage.delete(key: _derivedKeyName);
    await _storage.delete(key: _phraseHashName);
  }

  /// Derives a 256-bit master key from the recovery phrase using PBKDF2.
  ///
  /// Uses a fixed salt (the app identifier) plus the phrase itself as the
  /// password. This is deterministic — the same phrase always produces
  /// the same key.
  static Future<Uint8List> deriveMasterKey(RecoveryPhrase phrase) async {
    return Isolate.run(() => _deriveMasterKeySync(phrase.toPhrase()));
  }

  static Future<Uint8List> _deriveMasterKeySync(String phraseString) async {
    // PBKDF2 with SHA-256, 100,000 iterations.
    // Salt is derived from the app identifier for deterministic derivation.
    const salt = 'LifeOS.RecoveryPhrase.v1';
    final saltBytes = Uint8List.fromList(utf8.encode(salt));

    final pbkdf2 = DartPbkdf2(
      macAlgorithm: DartHmac(const DartSha256()),
      iterations: 100000,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(phraseString)),
      nonce: saltBytes,
    );

    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Computes a quick check hash from a phrase for UI validation.
  static String hashPhrase(RecoveryPhrase phrase) => phrase.toHash();
}
