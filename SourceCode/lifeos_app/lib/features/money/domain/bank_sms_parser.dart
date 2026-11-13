// Pure SMS parsing logic for PBI-040 — no platform dependencies.
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Transaction type extracted from SMS.
enum TransactionType { debit, credit }

/// A parsed bank transaction from SMS.
class ParsedTransaction {
  const ParsedTransaction({
    required this.smsSender,
    required this.smsBody,
    required this.smsTimestamp,
    required this.amountMinor,
    required this.transactionType,
    this.merchant,
    this.accountMasked,
    this.cardMasked,
    this.balance,
  });

  final String smsSender;
  final String smsBody;
  final DateTime smsTimestamp;
  final int amountMinor;
  final TransactionType transactionType;
  final String? merchant;
  final String? accountMasked;
  final String? cardMasked;
  final int? balance; // Remaining balance in minor units, if present

  /// SHA-256 hash for deduplication: sender + timestamp + amount + type.
  String get smsHash {
    final data = '$smsSender|${smsTimestamp.millisecondsSinceEpoch}|'
        '$amountMinor|${transactionType.name}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  @override
  String toString() =>
      'ParsedTransaction(${transactionType.name}: $amountMinor from $smsSender)';
}

/// Known bank sender IDs in Pakistan.
const bankSenderIds = <String, String>{
  // HBL
  'HBL': 'HBL',
  'HBL-Alert': 'HBL',
  'HBLKonnect': 'HBL',
  'HBLPK': 'HBL',
  // UBL
  'UBL': 'UBL',
  'UBL-Alert': 'UBL',
  'UBLPK': 'UBL',
  // MCB
  'MCB': 'MCB',
  'MCB-Alert': 'MCB',
  'MCBPK': 'MCB',
  // Meezan
  'Meezan': 'Meezan',
  'MBL': 'Meezan',
  'MeezanBnk': 'Meezan',
  // Allied
  'ABL': 'Allied',
  'ABL-Alert': 'Allied',
  // Askari
  'AKBL': 'Askari',
  'Askari': 'Askari',
  // Bank Alfalah
  'Alfalah': 'Alfalah',
  'BAF': 'Alfalah',
  'BankAlfalah': 'Alfalah',
  // Faysal
  'FBL': 'Faysal',
  'Faysal': 'Faysal',
  // Standard Chartered
  'SCB': 'SCB',
  'StanChart': 'SCB',
  // Habib Metro
  'HMB': 'HabibMetro',
  'HabibMetro': 'HabibMetro',
  // JazzCash
  'JazzCash': 'JazzCash',
  'Jazz': 'JazzCash',
  'JAZZCASH': 'JazzCash',
  // Easypaisa
  'Easypaisa': 'Easypaisa',
  'EP': 'Easypaisa',
  'EASYPAISA': 'Easypaisa',
  // SadaPay
  'SadaPay': 'SadaPay',
  'SADAPAY': 'SadaPay',
  // NayaPay
  'NayaPay': 'NayaPay',
  'NAYAPAY': 'NayaPay',
};

/// Check if a sender ID is a known bank.
bool isBankSender(String sender) {
  final normalized = sender.trim().toUpperCase();
  return bankSenderIds.keys.any(
    (k) => k.toUpperCase() == normalized || normalized.contains(k.toUpperCase()),
  );
}

/// Normalize bank name from sender ID.
String? normalizeBankName(String sender) {
  final normalized = sender.trim();
  for (final entry in bankSenderIds.entries) {
    if (entry.key.toUpperCase() == normalized.toUpperCase() ||
        normalized.toUpperCase().contains(entry.key.toUpperCase())) {
      return entry.value;
    }
  }
  return null;
}

/// Parse amount from SMS text. Returns amount in minor units (paisa).
/// Handles formats: "Rs. 1,234.56", "PKR 1234", "Rs1,234", "1,234/-"
int? parseAmount(String text) {
  // Try multiple patterns for amount extraction
  final patterns = [
    // Rs. 1,234.56 or Rs 1,234 or Rs.1234 or PKR 1,234.00
    RegExp(r'(?:Rs\.?|PKR)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // 1,234/- format
    RegExp(r'([\d,]+)/-'),
    // Amount: 1234 or Amt: 1234
    RegExp(r'(?:Amount|Amt)[:\s]*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    // Standalone large number with commas (likely amount)
    RegExp(r'\b([\d]{1,3}(?:,\d{3})+(?:\.\d{1,2})?)\b'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final amountStr = match.group(1)!.replaceAll(',', '');
      final amount = double.tryParse(amountStr);
      if (amount != null && amount > 0) {
        // Convert to minor units (paisa = rupees * 100)
        return (amount * 100).round();
      }
    }
  }
  return null;
}

/// Extract masked account number (e.g., "***1234" or "XXXX5678").
String? extractAccountMask(String text) {
  final patterns = [
    RegExp(r'A/C\s*[*X]*(\d{4})', caseSensitive: false),
    RegExp(r'account\s*[*X]*(\d{4})', caseSensitive: false),
    RegExp(r'[*X]{3,}(\d{4})'),
    RegExp(r'ending\s*(\d{4})', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      return '***${match.group(1)}';
    }
  }
  return null;
}

/// Extract masked card number (e.g., "****5678").
String? extractCardMask(String text) {
  final patterns = [
    RegExp(r'card\s*[*X]*(\d{4})', caseSensitive: false),
    RegExp(r'[*X]{4,}(\d{4})'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      return '****${match.group(1)}';
    }
  }
  return null;
}

/// Extract merchant/description from SMS.
String? extractMerchant(String text) {
  final patterns = [
    // "at MERCHANT_NAME" or "at MERCHANT NAME on"
    RegExp(r'\bat\s+([A-Z][A-Z0-9\s&\-\.]+?)(?:\s+on|\s+for|\s+dated|\s*$)', caseSensitive: false),
    // "to RECIPIENT" for transfers
    RegExp(r'\bto\s+([A-Z][A-Z0-9\s&\-\.]+?)(?:\s+on|\s+for|\s+dated|\s+from|\s*$)', caseSensitive: false),
    // "for DESCRIPTION"
    RegExp(r'\bfor\s+([A-Z][A-Z0-9\s&\-\.]+?)(?:\s+on|\s+dated|\s*$)', caseSensitive: false),
    // "from SENDER" for credits
    RegExp(r'\bfrom\s+([A-Z][A-Z0-9\s&\-\.]+?)(?:\s+on|\s+dated|\s*$)', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final merchant = match.group(1)!.trim();
      // Filter out common non-merchant words
      if (!_isNonMerchant(merchant)) {
        return _cleanMerchant(merchant);
      }
    }
  }
  return null;
}

bool _isNonMerchant(String text) {
  final lower = text.toLowerCase();
  const nonMerchants = [
    'your', 'the', 'a', 'an', 'account', 'card', 'balance', 'amount',
    'transaction', 'transfer', 'payment', 'debit', 'credit',
  ];
  return nonMerchants.any((w) => lower == w || lower.startsWith('$w '));
}

String _cleanMerchant(String merchant) {
  // Clean up merchant name: trim, collapse spaces, title case
  return merchant
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

/// Extract remaining balance from SMS.
int? extractBalance(String text) {
  final patterns = [
    RegExp(r'(?:Bal|Balance)[:\s]*(?:Rs\.?|PKR)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    RegExp(r'(?:Avl|Available)[:\s]*(?:Rs\.?|PKR)?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final balStr = match.group(1)!.replaceAll(',', '');
      final bal = double.tryParse(balStr);
      if (bal != null && bal >= 0) {
        return (bal * 100).round();
      }
    }
  }
  return null;
}

/// Determine if SMS is a debit or credit transaction.
TransactionType? detectTransactionType(String text) {
  final lower = text.toLowerCase();
  
  // Debit indicators
  const debitWords = [
    'debited', 'debit', 'spent', 'withdrawn', 'withdrawal', 'purchase',
    'paid', 'payment', 'sent', 'transferred out', 'deducted',
  ];
  
  // Credit indicators
  const creditWords = [
    'credited', 'credit', 'received', 'deposited', 'deposit',
    'salary', 'refund', 'cashback', 'transferred in', 'added',
  ];

  for (final word in debitWords) {
    if (lower.contains(word)) return TransactionType.debit;
  }
  for (final word in creditWords) {
    if (lower.contains(word)) return TransactionType.credit;
  }
  
  return null;
}

/// Check if SMS should be filtered out (OTP, promo, etc.).
bool shouldFilterSms(String text) {
  final lower = text.toLowerCase();
  const filterWords = [
    'otp', 'verification', 'verify', 'code is', 'pin is',
    'one time password', 'do not share',
    'offer', 'win', 'lucky', 'congratulations', 'prize',
    'subscribe', 'unsubscribe', 'click here', 'download app',
    'failed', 'declined', 'unsuccessful', 'rejected', 'cancelled',
    'reversed', 'reversal',
  ];
  
  return filterWords.any((w) => lower.contains(w));
}

/// Parse a single SMS into a transaction (if valid).
ParsedTransaction? parseSms({
  required String sender,
  required String body,
  required DateTime timestamp,
}) {
  // Check if from a known bank
  if (!isBankSender(sender)) return null;
  
  // Filter out OTP, promo, failed transactions
  if (shouldFilterSms(body)) return null;
  
  // Must have an amount
  final amount = parseAmount(body);
  if (amount == null || amount <= 0) return null;
  
  // Must have a transaction type
  final type = detectTransactionType(body);
  if (type == null) return null;
  
  return ParsedTransaction(
    smsSender: normalizeBankName(sender) ?? sender,
    smsBody: body,
    smsTimestamp: timestamp,
    amountMinor: amount,
    transactionType: type,
    merchant: extractMerchant(body),
    accountMasked: extractAccountMask(body),
    cardMasked: extractCardMask(body),
    balance: extractBalance(body),
  );
}

/// Guess expense category from merchant name.
String? guessCategory(String? merchant) {
  if (merchant == null) return null;
  
  final lower = merchant.toLowerCase();
  
  // Fuel/Transport
  if (_matchesAny(lower, ['shell', 'pso', 'total', 'caltex', 'petrol', 'fuel', 'careem', 'uber', 'indriver'])) {
    return 'transport';
  }
  
  // Groceries
  if (_matchesAny(lower, ['metro', 'imtiaz', 'alfatah', 'naheed', 'carrefour', 'hyperstar', 'chase', 'grocery', 'mart'])) {
    return 'groceries';
  }
  
  // Food/Dining
  if (_matchesAny(lower, ['restaurant', 'cafe', 'pizza', 'kfc', 'mcdonald', 'burger', 'food', 'eat', 'dine'])) {
    return 'food';
  }
  
  // Utilities
  if (_matchesAny(lower, ['kelectric', 'k-electric', 'ssgc', 'sui gas', 'wapda', 'lesco', 'fesco', 'electric', 'gas bill'])) {
    return 'utilities';
  }
  
  // Mobile/Internet
  if (_matchesAny(lower, ['jazz', 'telenor', 'zong', 'ufone', 'ptcl', 'nayatel', 'stormfiber'])) {
    return 'mobile';
  }
  
  // Medical
  if (_matchesAny(lower, ['pharmacy', 'hospital', 'clinic', 'medical', 'doctor', 'lab', 'diagnostic'])) {
    return 'medical';
  }
  
  // Shopping
  if (_matchesAny(lower, ['daraz', 'amazon', 'shopping', 'mall', 'store', 'outlet'])) {
    return 'shopping';
  }
  
  return null;
}

bool _matchesAny(String text, List<String> keywords) {
  return keywords.any((k) => text.contains(k));
}
