// Where the user's API key lives (PBI-027a AC6).
//
// Secure storage only: never the Drift database, never the export ZIP
// (PBI-025), never a log line (PBI-030).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

/// Android Keystore / iOS Keychain.
class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _name = 'lifeos.ai_api_key.v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String value) => _storage.write(key: _name, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _name);
}

/// In memory, for tests and the web preview.
class MemorySecretStore implements SecretStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}
