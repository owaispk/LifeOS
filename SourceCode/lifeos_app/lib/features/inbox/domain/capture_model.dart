// Quick Capture domain model (PBI-026).

import '../../../data/db/app_database.dart';

/// How the capture was created.
enum CaptureType {
  text('text'),
  voice('voice'),
  photo('photo'),
  file('file');

  const CaptureType(this.value);
  final String value;

  static CaptureType fromString(String value) {
    return CaptureType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => CaptureType.text,
    );
  }

  String get icon => switch (this) {
    text => '📝',
    voice => '🎤',
    photo => '📸',
    file => '📄',
  };
}

/// Processing status of a capture.
enum CaptureStatus {
  pending('pending'),
  done('done'),
  deleted('deleted');

  const CaptureStatus(this.value);
  final String value;

  static CaptureStatus fromString(String value) {
    return CaptureStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CaptureStatus.pending,
    );
  }
}

/// What kind of item the capture becomes.
enum DestinationType {
  task('task'),
  expense('expense'),
  document('document'),
  note('note');

  const DestinationType(this.value);
  final String value;

  static DestinationType? fromString(String? value) {
    if (value == null) return null;
    return DestinationType.values.where((d) => d.value == value).firstOrNull;
  }
}

/// Extension for working with Capture rows.
extension CaptureX on Capture {
  CaptureType get type => CaptureType.fromString(captureType);
  CaptureStatus get statusEnum => CaptureStatus.fromString(status);
  DestinationType? get destination => DestinationType.fromString(destinationType);

  bool get isPending => statusEnum == CaptureStatus.pending;
  bool get isDone => statusEnum == CaptureStatus.done;
  bool get isDeleted => statusEnum == CaptureStatus.deleted;

  /// Display text: content for text/voice, filename for photo/file.
  String get displayText {
    if (content != null && content!.isNotEmpty) return content!;
    if (mediaPath != null) {
      final parts = mediaPath!.split('/');
      return parts.isNotEmpty ? parts.last : mediaPath!;
    }
    return '';
  }

  /// When this was captured (updatedAt from sync columns).
  DateTime get capturedAt => DateTime.fromMillisecondsSinceEpoch(updatedAt);
}
