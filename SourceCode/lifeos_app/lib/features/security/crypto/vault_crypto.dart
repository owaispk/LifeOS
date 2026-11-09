import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the Master Key lives (PBI-024). Never logged, never written
/// anywhere else.
abstract interface class KeyStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List key);
  Future<void> clear();
}

/// Android Keystore / iOS Keychain-backed storage.
class SecureKeyStore implements KeyStore {
  const SecureKeyStore();

  static const _name = 'lifeos.master_key.v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<Uint8List?> read() async {
    final v = await _storage.read(key: _name);
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<void> write(Uint8List key) =>
      _storage.write(key: _name, value: base64Encode(key));

  @override
  Future<void> clear() => _storage.delete(key: _name);
}

/// In-memory key store for tests and the web preview.
class MemoryKeyStore implements KeyStore {
  Uint8List? _key;

  @override
  Future<Uint8List?> read() async => _key;

  @override
  Future<void> write(Uint8List key) async => _key = key;

  @override
  Future<void> clear() async => _key = null;
}

/// One encrypted file: ciphertext (with its GCM tag) plus what the row
/// stores: the nonce and the wrapped file key.
class EncryptedBlob {
  const EncryptedBlob(this.bytes, this.iv, this.wrappedKey);

  /// ciphertext ‖ 16-byte tag.
  final Uint8List bytes;

  /// base64 12-byte nonce (`document_files.enc_iv`).
  final String iv;

  /// base64 nonce ‖ wrapped FK ‖ tag (`document_files.enc_key_wrapped`).
  final String wrappedKey;
}

/// AES-256-GCM: a random file key (FK) per file, wrapped by the Master Key
/// (MK). Tampering with a file or a wrapped key fails authentication.
class VaultCrypto {
  VaultCrypto(this._store);

  final KeyStore _store;
  Uint8List? _mk;

  static final _rng = Random.secure();

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  /// The Master Key, created on first use.
  Future<Uint8List> _masterKey() async {
    final cached = _mk;
    if (cached != null) return cached;
    var mk = await _store.read();
    if (mk == null) {
      mk = randomBytes(32);
      await _store.write(mk);
    }
    return _mk = mk;
  }

  /// Forgets the cached key (after "Delete all local data").
  void forget() => _mk = null;

  Future<EncryptedBlob> encrypt(Uint8List plain) async {
    final mk = await _masterKey();
    final fk = randomBytes(32);
    final nonce = randomBytes(12);
    final wrapNonce = randomBytes(12);
    return Isolate.run(() => _encryptSync(plain, mk, fk, nonce, wrapNonce));
  }

  /// Decrypts in memory. Throws [SecretBoxAuthenticationError] if the file
  /// or its wrapped key was altered.
  Future<Uint8List> decrypt(
    Uint8List cipher,
    String iv,
    String wrappedKey,
  ) async {
    final mk = await _masterKey();
    return Isolate.run(() => _decryptSync(cipher, iv, wrappedKey, mk));
  }
}

const _tagLength = 16;

Future<EncryptedBlob> _encryptSync(
  Uint8List plain,
  Uint8List mk,
  Uint8List fk,
  Uint8List nonce,
  Uint8List wrapNonce,
) async {
  final aes = DartAesGcm.with256bits();
  final box = await aes.encrypt(plain, secretKey: SecretKey(fk), nonce: nonce);
  final wrapped = await aes.encrypt(
    fk,
    secretKey: SecretKey(mk),
    nonce: wrapNonce,
  );
  return EncryptedBlob(
    Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    base64Encode(nonce),
    base64Encode([...wrapNonce, ...wrapped.cipherText, ...wrapped.mac.bytes]),
  );
}

Future<Uint8List> _decryptSync(
  Uint8List cipher,
  String iv,
  String wrappedKey,
  Uint8List mk,
) async {
  final aes = DartAesGcm.with256bits();
  final w = base64Decode(wrappedKey);
  final fk = await aes.decrypt(
    SecretBox(
      w.sublist(12, w.length - _tagLength),
      nonce: w.sublist(0, 12),
      mac: Mac(w.sublist(w.length - _tagLength)),
    ),
    secretKey: SecretKey(mk),
  );
  if (cipher.length < _tagLength) {
    throw SecretBoxAuthenticationError();
  }
  final plain = await aes.decrypt(
    SecretBox(
      cipher.sublist(0, cipher.length - _tagLength),
      nonce: base64Decode(iv),
      mac: Mac(cipher.sublist(cipher.length - _tagLength)),
    ),
    secretKey: SecretKey(fk),
  );
  return Uint8List.fromList(plain);
}
