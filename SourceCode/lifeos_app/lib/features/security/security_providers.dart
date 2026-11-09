import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import 'crypto/vault_crypto.dart';
import 'crypto/vault_files.dart';

/// Master Key storage: the device keystore in the app, memory in tests.
final keyStoreProvider = Provider<KeyStore>((ref) => MemoryKeyStore());

final vaultCryptoProvider = Provider<VaultCrypto>(
  (ref) => VaultCrypto(ref.watch(keyStoreProvider)),
);

final vaultFilesProvider = Provider<VaultFiles>(
  (ref) => VaultFiles(
    ref.watch(repositoriesProvider),
    ref.watch(vaultCryptoProvider),
  ),
);
