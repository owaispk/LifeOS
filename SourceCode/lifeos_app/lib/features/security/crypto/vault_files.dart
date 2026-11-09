import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import 'vault_crypto.dart';

/// Reads and migrates Vault files (PBI-024). Files on disk are ciphertext;
/// they are decrypted into memory only.
class VaultFiles {
  VaultFiles(this._repos, this.crypto);

  final Repositories _repos;
  final VaultCrypto crypto;

  /// The plaintext bytes of [f], decrypted in memory. Files saved before
  /// encryption (no `enc_iv`) are read as-is until [migrate] runs.
  Future<Uint8List> read(DocumentFile f) async {
    final raw = await File(f.localPath!).readAsBytes();
    if (f.encIv == null || f.encKeyWrapped == null) return raw;
    try {
      return await crypto.decrypt(raw, f.encIv!, f.encKeyWrapped!);
    } on Object {
      // A migration interrupted between the row update and the file swap
      // leaves the plaintext original in place: still readable.
      if (looksPlain(raw)) return raw;
      rethrow;
    }
  }

  /// PDF (`%PDF`) or JPEG (`FF D8`) header — plaintext on disk.
  static bool looksPlain(Uint8List b) =>
      (b.length > 4 &&
          b[0] == 0x25 &&
          b[1] == 0x50 &&
          b[2] == 0x44 &&
          b[3] == 0x46) ||
      (b.length > 2 && b[0] == 0xFF && b[1] == 0xD8);

  /// Encrypts every file still stored as plaintext (Sprint 1–5 data), in
  /// place, once. Returns how many were encrypted.
  Future<int> migrate() async {
    var n = 0;
    // File rows stay live while their document sits in Trash, so this
    // covers trashed documents too.
    final files = await _repos.documentFiles.getWhere(
      (f) => f.encIv.isNull() & f.localPath.isNotNull(),
    );
    for (final f in files) {
      final file = File(f.localPath!);
      if (!await file.exists()) continue;
      final blob = await crypto.encrypt(await file.readAsBytes());
      // Record the keys first, then swap the ciphertext in under the real
      // name: if the swap never happens, [read] still finds the plaintext.
      await _repos.documentFiles.update(
        f.id,
        DocumentFilesCompanion(
          encIv: Value(blob.iv),
          encKeyWrapped: Value(blob.wrappedKey),
          sha256: Value(sha256.convert(blob.bytes).toString()),
        ),
      );
      final tmp = File('${file.path}.enc');
      await tmp.writeAsBytes(blob.bytes, flush: true);
      await tmp.rename(file.path);
      n++;
    }
    return n;
  }
}
