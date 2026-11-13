import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/money/domain/bank_sms_parser.dart';

void main() {
  group('BankSmsParser', () {
    group('isBankSender', () {
      test('identifies HBL senders', () {
        expect(isBankSender('HBL'), isTrue);
        expect(isBankSender('HBL-Alert'), isTrue);
        expect(isBankSender('HBLKonnect'), isTrue);
      });

      test('identifies JazzCash and Easypaisa', () {
        expect(isBankSender('JazzCash'), isTrue);
        expect(isBankSender('Easypaisa'), isTrue);
        expect(isBankSender('JAZZCASH'), isTrue);
      });

      test('identifies digital banks', () {
        expect(isBankSender('SadaPay'), isTrue);
        expect(isBankSender('NayaPay'), isTrue);
      });

      test('rejects non-bank senders', () {
        expect(isBankSender('PIZZA-HUT'), isFalse);
        expect(isBankSender('CAREEM'), isFalse);
        expect(isBankSender('123456'), isFalse);
      });
    });

    group('parseAmount', () {
      test('parses Rs. format', () {
        expect(parseAmount('Rs. 5,000 debited'), equals(500000));
        expect(parseAmount('Rs.1,234.50 spent'), equals(123450));
        expect(parseAmount('Rs 45000 paid'), equals(4500000));
      });

      test('parses PKR format', () {
        expect(parseAmount('PKR 2,500.00 debited'), equals(250000));
        expect(parseAmount('PKR 150,000 credited'), equals(15000000));
      });

      test('parses /- format', () {
        expect(parseAmount('Amount 5,000/- debited'), equals(500000));
      });

      test('handles decimal amounts', () {
        expect(parseAmount('Rs. 1,234.99 spent'), equals(123499));
        expect(parseAmount('PKR 500.50 paid'), equals(50050));
      });

      test('returns null for invalid amounts', () {
        expect(parseAmount('No amount here'), isNull);
        expect(parseAmount('Rs. 0 debited'), isNull);
        expect(parseAmount('Rs. -100 error'), isNull);
      });
    });

    group('extractAccountMask', () {
      test('extracts account ending digits', () {
        expect(extractAccountMask('A/C ***1234'), equals('***1234'));
        expect(extractAccountMask('account ending 5678'), equals('***5678'));
        expect(extractAccountMask('from A/C XXXX9012'), equals('***9012'));
      });

      test('returns null when no account found', () {
        expect(extractAccountMask('No account info'), isNull);
      });
    });

    group('extractCardMask', () {
      test('extracts card ending digits', () {
        expect(extractCardMask('card ****5678'), equals('****5678'));
        expect(extractCardMask('Card XXXX1234'), equals('****1234'));
      });
    });

    group('extractMerchant', () {
      test('extracts merchant from "at" pattern', () {
        expect(extractMerchant('spent at SHELL PUMP'), equals('Shell Pump'));
        expect(extractMerchant('paid at METRO CASH'), equals('Metro Cash'));
      });

      test('extracts recipient from "to" pattern', () {
        expect(extractMerchant('sent to JOHN DOE'), equals('John Doe'));
      });

      test('extracts from "for" pattern', () {
        expect(extractMerchant('paid for ELECTRICITY BILL'), equals('Electricity Bill'));
      });

      test('returns null when no merchant found', () {
        expect(extractMerchant('Rs 5000 debited'), isNull);
      });
    });

    group('detectTransactionType', () {
      test('detects debit transactions', () {
        expect(detectTransactionType('Rs 5000 debited'), TransactionType.debit);
        expect(detectTransactionType('Amount spent at SHELL'), TransactionType.debit);
        expect(detectTransactionType('Withdrawn from ATM'), TransactionType.debit);
        expect(detectTransactionType('Payment of Rs 2500'), TransactionType.debit);
      });

      test('detects credit transactions', () {
        expect(detectTransactionType('Rs 50000 credited'), TransactionType.credit);
        expect(detectTransactionType('Received PKR 10000'), TransactionType.credit);
        expect(detectTransactionType('Salary deposited'), TransactionType.credit);
        expect(detectTransactionType('Refund of Rs 500'), TransactionType.credit);
      });

      test('returns null for ambiguous text', () {
        expect(detectTransactionType('Account balance'), isNull);
      });
    });

    group('shouldFilterSms', () {
      test('filters OTP messages', () {
        expect(shouldFilterSms('Your OTP is 123456'), isTrue);
        expect(shouldFilterSms('Verification code: 9999'), isTrue);
        expect(shouldFilterSms('Do not share this PIN'), isTrue);
      });

      test('filters promotional messages', () {
        expect(shouldFilterSms('Win a lucky prize!'), isTrue);
        expect(shouldFilterSms('Special offer for you'), isTrue);
      });

      test('filters failed transactions', () {
        expect(shouldFilterSms('Transaction failed'), isTrue);
        expect(shouldFilterSms('Payment declined'), isTrue);
        expect(shouldFilterSms('Transaction reversed'), isTrue);
      });

      test('allows valid transaction messages', () {
        expect(shouldFilterSms('Rs 5000 debited from account'), isFalse);
        expect(shouldFilterSms('PKR 10000 credited to your account'), isFalse);
      });
    });

    group('parseSms', () {
      test('parses HBL debit SMS', () {
        final result = parseSms(
          sender: 'HBL',
          body: 'Rs. 5,000 debited from A/C ***1234 at SHELL PUMP on 13-Nov-26. Bal: Rs. 45,000',
          timestamp: DateTime(2026, 11, 13, 14, 30),
        );

        expect(result, isNotNull);
        expect(result!.smsSender, equals('HBL'));
        expect(result.amountMinor, equals(500000));
        expect(result.transactionType, TransactionType.debit);
        expect(result.merchant, equals('Shell Pump'));
        expect(result.accountMasked, equals('***1234'));
        expect(result.balance, equals(4500000));
      });

      test('parses JazzCash credit SMS', () {
        final result = parseSms(
          sender: 'JazzCash',
          body: 'PKR 10,000 received from EMPLOYER on 01-Nov-26. New balance: Rs. 25,000',
          timestamp: DateTime(2026, 11, 1, 10, 0),
        );

        expect(result, isNotNull);
        expect(result!.smsSender, equals('JazzCash'));
        expect(result.amountMinor, equals(1000000));
        expect(result.transactionType, TransactionType.credit);
      });

      test('parses Easypaisa transaction', () {
        final result = parseSms(
          sender: 'Easypaisa',
          body: 'Rs.2,500 paid to K-ELECTRIC for electricity bill. Bal: Rs.8,000',
          timestamp: DateTime(2026, 11, 10, 16, 45),
        );

        expect(result, isNotNull);
        expect(result!.amountMinor, equals(250000));
        expect(result.transactionType, TransactionType.debit);
      });

      test('returns null for non-bank sender', () {
        final result = parseSms(
          sender: 'PIZZA-HUT',
          body: 'Your order of Rs. 2,500 is confirmed',
          timestamp: DateTime.now(),
        );
        expect(result, isNull);
      });

      test('returns null for OTP message', () {
        final result = parseSms(
          sender: 'HBL',
          body: 'Your OTP is 123456. Do not share.',
          timestamp: DateTime.now(),
        );
        expect(result, isNull);
      });

      test('returns null when no amount found', () {
        final result = parseSms(
          sender: 'HBL',
          body: 'Your account statement is ready',
          timestamp: DateTime.now(),
        );
        expect(result, isNull);
      });

      test('generates unique hash for dedup', () {
        final sms1 = parseSms(
          sender: 'HBL',
          body: 'Rs. 5,000 debited from A/C ***1234',
          timestamp: DateTime(2026, 11, 13, 14, 30),
        );
        final sms2 = parseSms(
          sender: 'HBL',
          body: 'Rs. 5,000 debited from A/C ***1234',
          timestamp: DateTime(2026, 11, 13, 14, 31), // 1 minute later
        );

        expect(sms1!.smsHash, isNot(equals(sms2!.smsHash)));
      });
    });

    group('guessCategory', () {
      test('guesses transport for fuel stations', () {
        expect(guessCategory('SHELL PUMP'), equals('transport'));
        expect(guessCategory('PSO STATION'), equals('transport'));
        expect(guessCategory('CAREEM RIDE'), equals('transport'));
      });

      test('guesses groceries for supermarkets', () {
        expect(guessCategory('METRO CASH'), equals('groceries'));
        expect(guessCategory('IMTIAZ SUPER'), equals('groceries'));
        expect(guessCategory('CARREFOUR'), equals('groceries'));
      });

      test('guesses utilities for electricity/gas', () {
        expect(guessCategory('K-ELECTRIC'), equals('utilities'));
        expect(guessCategory('SSGC'), equals('utilities'));
      });

      test('guesses mobile for telecoms', () {
        expect(guessCategory('JAZZ TOPUP'), equals('mobile'));
        expect(guessCategory('TELENOR'), equals('mobile'));
        expect(guessCategory('PTCL'), equals('mobile'));
      });

      test('returns null for unknown merchants', () {
        expect(guessCategory('RANDOM SHOP'), isNull);
        expect(guessCategory(null), isNull);
      });
    });

    group('Real-world SMS samples', () {
      test('HBL debit card transaction', () {
        final result = parseSms(
          sender: 'HBL-Alert',
          body: 'Rs.2,350 has been debited from your A/C ***4521 at TOTAL PARCO on 13-NOV-26 17:45. Avl Bal: Rs.125,430',
          timestamp: DateTime(2026, 11, 13, 17, 45),
        );
        expect(result, isNotNull);
        expect(result!.amountMinor, equals(235000));
        expect(result.transactionType, TransactionType.debit);
        expect(result.accountMasked, equals('***4521'));
      });

      test('UBL salary credit', () {
        final result = parseSms(
          sender: 'UBL',
          body: 'PKR 150,000.00 has been credited to your account ending 7890 on 01-NOV-26. Salary from TECH COMPANY',
          timestamp: DateTime(2026, 11, 1, 10, 0),
        );
        expect(result, isNotNull);
        expect(result!.amountMinor, equals(15000000));
        expect(result.transactionType, TransactionType.credit);
      });

      test('MCB ATM withdrawal', () {
        final result = parseSms(
          sender: 'MCB',
          body: 'Rs.20,000 withdrawn from ATM using card ****1234 on 10-NOV-26. Available balance Rs.80,500',
          timestamp: DateTime(2026, 11, 10, 15, 30),
        );
        expect(result, isNotNull);
        expect(result!.amountMinor, equals(2000000));
        expect(result.transactionType, TransactionType.debit);
        expect(result.cardMasked, equals('****1234'));
      });

      test('SadaPay merchant payment', () {
        final result = parseSms(
          sender: 'SadaPay',
          body: 'Payment of Rs.3,499 to DARAZ for online purchase. Card ****5678. Bal: Rs.12,501',
          timestamp: DateTime(2026, 11, 12, 20, 15),
        );
        expect(result, isNotNull);
        expect(result!.amountMinor, equals(349900));
        expect(result.transactionType, TransactionType.debit);
      });

      test('Meezan Bank bill payment', () {
        final result = parseSms(
          sender: 'Meezan',
          body: 'Rs.8,500/- paid for PTCL bill from A/C ***3456. Bal Rs.41,200',
          timestamp: DateTime(2026, 11, 5, 11, 0),
        );
        expect(result, isNotNull);
        expect(result!.amountMinor, equals(850000));
        expect(result.transactionType, TransactionType.debit);
      });
    });
  });
}
