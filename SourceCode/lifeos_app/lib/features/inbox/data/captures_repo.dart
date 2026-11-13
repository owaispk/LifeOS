// Captures repository with CRUD, soft-delete, and undo (PBI-026).

import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../domain/capture_model.dart';

/// CRUD operations for the Captures table.
class CapturesRepository {
  CapturesRepository(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  /// Creates a new text capture.
  Future<Capture> createText(String content) {
    return _repos.captures.insert(
      CapturesCompanion.insert(
        captureType: CaptureType.text.value,
        content: Value(content.trim()),
      ),
    );
  }

  /// Creates a new voice capture.
  Future<Capture> createVoice(String transcription, {String? mediaPath}) {
    return _repos.captures.insert(
      CapturesCompanion.insert(
        captureType: CaptureType.voice.value,
        content: Value(transcription.trim()),
        mediaPath: Value(mediaPath),
        mediaMime: const Value('audio/m4a'),
      ),
    );
  }

  /// Creates a new photo capture.
  Future<Capture> createPhoto({
    required String mediaPath,
    String? mediaMime,
    int? mediaSizeBytes,
  }) {
    return _repos.captures.insert(
      CapturesCompanion.insert(
        captureType: CaptureType.photo.value,
        mediaPath: Value(mediaPath),
        mediaMime: Value(mediaMime ?? 'image/jpeg'),
        mediaSizeBytes: Value(mediaSizeBytes),
      ),
    );
  }

  /// Creates a new file capture.
  Future<Capture> createFile({
    required String mediaPath,
    String? mediaMime,
    int? mediaSizeBytes,
  }) {
    return _repos.captures.insert(
      CapturesCompanion.insert(
        captureType: CaptureType.file.value,
        mediaPath: Value(mediaPath),
        mediaMime: Value(mediaMime ?? 'application/octet-stream'),
        mediaSizeBytes: Value(mediaSizeBytes),
      ),
    );
  }

  /// All pending captures, newest first.
  Future<List<Capture>> getPending() async {
    final all = await _repos.captures.getWhere(
      (c) => c.status.equals(CaptureStatus.pending.value),
    );
    return all..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Watch pending captures, newest first.
  Stream<List<Capture>> watchPending() {
    return _repos.captures
        .watchWhere((c) => c.status.equals(CaptureStatus.pending.value))
        .map((list) => list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
  }

  /// Count of pending captures (for badge).
  Stream<int> watchPendingCount() {
    return watchPending().map((list) => list.length);
  }

  /// Get a single capture by id.
  Future<Capture?> getById(String id) => _repos.captures.getById(id);

  /// Updates a capture's content.
  Future<Capture> updateContent(String id, String content) {
    return _repos.captures.update(
      id,
      CapturesCompanion(content: Value(content.trim())),
    );
  }

  /// Marks a capture as processed with its destination.
  Future<Capture> markProcessed({
    required String id,
    required DestinationType destinationType,
    required String destinationId,
    String? notes,
  }) {
    return _repos.captures.update(
      id,
      CapturesCompanion(
        status: Value(CaptureStatus.done.value),
        processedAt: Value(_now().millisecondsSinceEpoch),
        destinationType: Value(destinationType.value),
        destinationId: Value(destinationId),
        notes: Value(notes),
      ),
    );
  }

  /// Soft-deletes a capture. Returns the deleted capture for undo.
  Future<Capture> delete(String id) async {
    final capture = await _repos.captures.getById(id);
    if (capture == null) {
      throw StateError('Capture $id not found');
    }
    await _repos.captures.update(
      id,
      CapturesCompanion(status: Value(CaptureStatus.deleted.value)),
    );
    return capture;
  }

  /// Restores a deleted capture (undo).
  Future<Capture> restore(String id) {
    return _repos.captures.update(
      id,
      CapturesCompanion(
        status: Value(CaptureStatus.pending.value),
        processedAt: const Value(null),
        destinationType: const Value(null),
        destinationId: const Value(null),
      ),
    );
  }

  /// Hard-deletes all captures marked as deleted.
  Future<void> purgeDeleted() async {
    final deleted = await _repos.captures.getWhere(
      (c) => c.status.equals(CaptureStatus.deleted.value),
    );
    for (final capture in deleted) {
      await _repos.captures.softDelete(capture.id);
    }
  }
}
