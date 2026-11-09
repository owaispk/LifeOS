// PBI-024: AES-256-GCM at rest (AC1, AC2), migration of old files, and
// no key material in logs (AC6).
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/security/crypto/vault_crypto.dart';
import 'package:lifeos_app/features/security/crypto/vault_files.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../capture/image_fixtures.dart';

bool hasPlainHeader(Uint8List b) => VaultFiles.looksPlain(b);

void main() {
  group('VaultCrypto', () {
    test('AC2: encrypt → decrypt round-trips byte for byte', () async {
      final c = VaultCrypto(MemoryKeyStore());
      final plain = Uint8List.fromList(List.generate(100000, (i) => i % 251));
      final blob = await c.encrypt(plain);
      expect(blob.bytes.length, plain.length + 16, reason: 'GCM tag');
      expect(await c.decrypt(blob.bytes, blob.iv, blob.wrappedKey), plain);
    });

    test('AC2: a tampered file or wrapped key fails authentication', () async {
      final c = VaultCrypto(MemoryKeyStore());
      final blob = await c.encrypt(Uint8List.fromList([1, 2, 3, 4, 5]));
      final bad = Uint8List.fromList(blob.bytes)..[0] ^= 0x01;
      await expectLater(
        c.decrypt(bad, blob.iv, blob.wrappedKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final w = blob.wrappedKey.codeUnits.toList();
      w[20] = w[20] == 65 ? 66 : 65; // flip one base64 char
      await expectLater(
        c.decrypt(blob.bytes, blob.iv, String.fromCharCodes(w)),
        throwsA(anything),
      );
    });

    test('each file gets its own key and nonce', () async {
      final c = VaultCrypto(MemoryKeyStore());
      final a = await c.encrypt(Uint8List.fromList([7, 7, 7]));
      final b = await c.encrypt(Uint8List.fromList([7, 7, 7]));
      expect(a.bytes, isNot(b.bytes));
      expect(a.iv, isNot(b.iv));
      expect(a.wrappedKey, isNot(b.wrappedKey));
    });

    test('the Master Key is created once and kept in the key store', () async {
      final store = MemoryKeyStore();
      final blob = await VaultCrypto(store).encrypt(Uint8List(10));
      final mk = await store.read();
      expect(mk, hasLength(32));
      // A fresh instance over the same store can still decrypt.
      expect(
        await VaultCrypto(store).decrypt(blob.bytes, blob.iv, blob.wrappedKey),
        Uint8List(10),
      );
      // Another device's key cannot.
      await expectLater(
        VaultCrypto(MemoryKeyStore())
            .decrypt(blob.bytes, blob.iv, blob.wrappedKey),
        throwsA(anything),
      );
    });
  });

  group('files on disk (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    late Directory tmp;
    late VaultCrypto crypto;

    setUp(() async {
      db = memoryDb();
      await openLocalData(db);
      repos = await Repositories.open(db);
      tmp = await Directory.systemTemp.createTemp('lifeos_crypto_');
      crypto = VaultCrypto(MemoryKeyStore());
    });
    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    String page(String name) {
      final f = File(p.join(tmp.path, name))
        ..writeAsBytesSync(jpeg(fakeDocument(width: 120, height: 160)));
      return f.path;
    }

    test('AC1: saved files are never plaintext; reads decrypt', () async {
      final capture = CaptureService(
        repos,
        Directory(p.join(tmp.path, 'vault')),
        crypto: crypto,
      );
      for (final format in OutputFormat.values) {
        final doc = await capture.save(
          CaptureDraft.scan([page('a.jpg'), page('b.jpg')]),
          FilingDetails(title: 'Passport', format: format),
        );
        final files = await repos.documentFiles.getWhere(
          (f) => f.documentId.equals(doc.id),
        );
        for (final f in files) {
          final raw = File(f.localPath!).readAsBytesSync();
          expect(hasPlainHeader(raw), isFalse, reason: '$format on disk');
          expect(f.encIv, isNotNull);
          expect(f.encKeyWrapped, isNotNull);
          final plain = await VaultFiles(repos, crypto).read(f);
          expect(hasPlainHeader(plain), isTrue, reason: '$format decrypted');
          expect(plain.length, f.byteSize);
        }
      }
    });

    test('old plaintext files are encrypted once, in place', () async {
      // Saved the Sprint 1–5 way: no crypto.
      final old = CaptureService(repos, Directory(p.join(tmp.path, 'vault')));
      final doc = await old.save(
        CaptureDraft.scan([page('c.jpg')]),
        const FilingDetails(title: 'Old scan'),
      );
      final before = (await repos.documentFiles.getWhere(
        (f) => f.documentId.equals(doc.id),
      )).single;
      final plain = File(before.localPath!).readAsBytesSync();
      expect(hasPlainHeader(plain), isTrue);

      final vault = VaultFiles(repos, crypto);
      expect(await vault.migrate(), 1);
      expect(await vault.migrate(), 0, reason: 'once');
      final after = (await repos.documentFiles.getById(before.id))!;
      expect(hasPlainHeader(File(after.localPath!).readAsBytesSync()), isFalse);
      expect(await vault.read(after), plain);
      expect(File('${after.localPath}.enc').existsSync(), isFalse);
    });
  });

  test('AC6: no key material is printed or logged', () {
    final offenders = <String>[];
    final logCall = RegExp(r'\b(print|debugPrint|log|developer\.log)\s*\(');
    final keyish = RegExp(
      r'\b(mk|fk|masterKey|_mk|secretKey|wrappedKey|wrapped|key)\b',
      caseSensitive: false,
    );
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final line in f.readAsLinesSync()) {
        if (logCall.hasMatch(line) && keyish.hasMatch(line)) {
          offenders.add('${f.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
    // The Master Key is only ever handed to the key store.
    final crypto = File('lib/features/security/crypto/vault_crypto.dart')
        .readAsStringSync();
    expect(RegExp(r'_store\.write\(').allMatches(crypto), hasLength(1));
  });
}
