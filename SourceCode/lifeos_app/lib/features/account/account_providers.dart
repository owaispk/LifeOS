// Riverpod providers for Account & Recovery (PBI-026a).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../data/data_providers.dart';
import 'domain/account_service.dart';
import 'domain/recovery_phrase.dart';

export 'domain/account_service.dart' show Account;
export 'domain/recovery_phrase.dart' show RecoveryPhrase;

/// Route names for account screens.
const createAccountRoute = '/settings/account/create';
const recoveryPhraseRoute = '/settings/account/phrase';
const verifyPhraseRoute = '/settings/account/verify';
const recoverAccountRoute = '/settings/account/recover';
const viewPhraseRoute = '/settings/account/view';

/// Account service provider.
final accountServiceProvider = Provider<AccountService>((ref) {
  final db = ref.watch(repositoriesProvider).db;
  return AccountService(db, IdGenerator());
});

/// Whether an account exists.
final hasAccountProvider = FutureProvider<bool>((ref) async {
  return ref.watch(accountServiceProvider).hasAccount();
});

/// Active account (null if none).
final activeAccountProvider = FutureProvider<Account?>((ref) async {
  return ref.watch(accountServiceProvider).getActiveAccount();
});

/// Recovery state.
class RecoveryState {
  const RecoveryState({
    this.phraseInput = '',
    this.isRecovering = false,
    this.error,
    this.success = false,
  });

  final String phraseInput;
  final bool isRecovering;
  final String? error;
  final bool success;

  RecoveryState copyWith({
    String? phraseInput,
    bool? isRecovering,
    String? error,
    bool? success,
  }) {
    return RecoveryState(
      phraseInput: phraseInput ?? this.phraseInput,
      isRecovering: isRecovering ?? this.isRecovering,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// Recovery flow notifier using Notifier pattern.
class AccountRecoveryNotifier extends Notifier<RecoveryState> {
  @override
  RecoveryState build() => const RecoveryState();

  AccountService get _service => ref.read(accountServiceProvider);

  void setPhrase(String phrase) {
    state = state.copyWith(phraseInput: phrase, error: null);
  }

  Future<bool> recover() async {
    return recoverWithPhrase(state.phraseInput);
  }

  Future<bool> recoverWithPhrase(String phraseString) async {
    state = state.copyWith(isRecovering: true, error: null);

    try {
      final phrase = RecoveryPhrase.parse(phraseString);
      if (phrase == null) {
        state = state.copyWith(
          isRecovering: false,
          error: 'Invalid recovery phrase format',
        );
        return false;
      }

      final success = await _service.recoverAccount(phrase);
      if (success) {
        state = state.copyWith(isRecovering: false, success: true);
        return true;
      } else {
        state = state.copyWith(
          isRecovering: false,
          error: 'Recovery phrase does not match any account',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isRecovering: false,
        error: 'Recovery failed: $e',
      );
      return false;
    }
  }

  void reset() {
    state = const RecoveryState();
  }
}

/// Account recovery provider.
final accountRecoveryProvider =
    NotifierProvider<AccountRecoveryNotifier, RecoveryState>(
  AccountRecoveryNotifier.new,
);

/// Verification challenge for phrase confirmation.
class VerificationChallenge {
  const VerificationChallenge({
    required this.indices,
    this.answers = const {},
  });

  final List<int> indices;
  final Map<int, String> answers;

  VerificationChallenge copyWith({
    List<int>? indices,
    Map<int, String>? answers,
  }) {
    return VerificationChallenge(
      indices: indices ?? this.indices,
      answers: answers ?? this.answers,
    );
  }
}

/// Account creation flow state.
class AccountCreationState {
  const AccountCreationState({
    this.phrase,
    this.step = AccountCreationStep.intro,
    this.challenge,
    this.error,
  });

  final RecoveryPhrase? phrase;
  final AccountCreationStep step;
  final VerificationChallenge? challenge;
  final String? error;

  AccountCreationState copyWith({
    RecoveryPhrase? phrase,
    AccountCreationStep? step,
    VerificationChallenge? challenge,
    String? error,
  }) {
    return AccountCreationState(
      phrase: phrase ?? this.phrase,
      step: step ?? this.step,
      challenge: challenge ?? this.challenge,
      error: error,
    );
  }
}

enum AccountCreationStep {
  intro,
  showPhrase,
  verify,
  complete,
}

/// Account creation flow controller.
class AccountCreationNotifier extends Notifier<AccountCreationState> {
  @override
  AccountCreationState build() => const AccountCreationState();

  /// Generate a new recovery phrase.
  RecoveryPhrase generatePhrase() {
    final phrase = RecoveryPhrase.generate();
    state = state.copyWith(
      phrase: phrase,
      step: AccountCreationStep.showPhrase,
    );
    return phrase;
  }

  /// Create verification challenge.
  void createChallenge() {
    final indices = RecoveryPhrase.getVerificationIndices();
    state = state.copyWith(
      challenge: VerificationChallenge(indices: indices),
      step: AccountCreationStep.verify,
    );
  }

  /// User confirmed they wrote down the phrase.
  void confirmWritten() {
    createChallenge();
  }

  /// Enter a verification word.
  void enterWord(int index, String word) {
    final challenge = state.challenge;
    if (challenge == null) return;

    final answers = Map<int, String>.from(challenge.answers);
    answers[index] = word.trim().toLowerCase();
    state = state.copyWith(
      challenge: challenge.copyWith(answers: answers),
    );
  }

  /// Verify the entered words.
  bool verifyChallenge() {
    final phrase = state.phrase;
    final challenge = state.challenge;
    if (phrase == null || challenge == null) return false;

    final words = phrase.words;
    for (final idx in challenge.indices) {
      final entered = challenge.answers[idx] ?? '';
      if (entered != words[idx]) {
        state = state.copyWith(error: 'Word ${idx + 1} is incorrect');
        return false;
      }
    }

    state = state.copyWith(
      step: AccountCreationStep.complete,
      error: null,
    );
    return true;
  }

  /// Create the account in the database.
  Future<Account> createAccount(String userId) async {
    final phrase = state.phrase;
    if (phrase == null) {
      throw StateError('No phrase generated');
    }
    final service = ref.read(accountServiceProvider);
    return service.createAccount(phrase: phrase, userId: userId);
  }

  /// Reset the flow.
  void reset() {
    state = const AccountCreationState();
  }
}

final accountCreationProvider =
    NotifierProvider<AccountCreationNotifier, AccountCreationState>(
  AccountCreationNotifier.new,
);
