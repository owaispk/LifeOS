import 'dart:io';

import 'package:flutter/services.dart';

import 'sms_transaction_service.dart';

/// Platform-specific SMS reader for PBI-040.
/// Only works on Android; iOS returns empty results.
class SmsReader {
  static const _channel = MethodChannel('com.lifeos.app/sms');

  /// Check if SMS reading is available on this platform.
  static bool get isAvailable => Platform.isAndroid;

  /// Check if we have SMS permission.
  static Future<bool> hasPermission() async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request SMS permission from the user.
  /// Returns true if granted.
  static Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Read SMS messages from the inbox.
  /// [since] - Only read messages after this timestamp (epoch ms).
  /// [limit] - Maximum number of messages to read.
  static Future<List<RawSms>> readSms({
    int? since,
    int limit = 100,
  }) async {
    if (!isAvailable) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('readSms', {
        'since': since,
        'limit': limit,
      });

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return RawSms(
          sender: map['sender'] as String,
          body: map['body'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        );
      }).toList();
    } on PlatformException catch (e) {
      // Log error but don't crash
      print('SmsReader error: ${e.message}');
      return [];
    }
  }

  /// Read only bank SMS messages (filtered by known sender IDs).
  static Future<List<RawSms>> readBankSms({
    int? since,
    int limit = 100,
  }) async {
    if (!isAvailable) return [];

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('readBankSms', {
        'since': since,
        'limit': limit,
      });

      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return RawSms(
          sender: map['sender'] as String,
          body: map['body'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        );
      }).toList();
    } on PlatformException catch (e) {
      print('SmsReader error: ${e.message}');
      return [];
    }
  }
}

/// Result of SMS sync operation.
class SmsSyncResult {
  const SmsSyncResult({
    required this.newTransactions,
    required this.totalProcessed,
    this.error,
  });

  final int newTransactions;
  final int totalProcessed;
  final String? error;

  bool get hasError => error != null;
}
