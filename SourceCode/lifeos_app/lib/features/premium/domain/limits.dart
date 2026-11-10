// Free-tier limits and the entitlement cache rules — pure Dart (PBI-029).
import '../../atc/domain/atc_schedule.dart' show freeTierRuleLimit;

export '../../atc/domain/atc_schedule.dart' show freeTierRuleLimit;

/// Documents the free plan holds (features spec §15). The ATC rule limit
/// lives with the ATC rules as [freeTierRuleLimit].
const freeTierDocumentLimit = 25;

/// Where the Vault starts saying how much room is left (AC8).
const documentsLeftWarnAt = 5;

/// How long a confirmed subscription is trusted without the store being
/// reachable again. The point is that a user who paid keeps what they
/// paid for on a plane or a dead network; only a store that answers can
/// take Premium away.
const entitlementTrust = Duration(days: 60);

/// How often the store is asked, at most.
const entitlementRecheck = Duration(hours: 1);

/// Premium is on when the cached entitlement has not run out. [until] is
/// epoch ms, null for never subscribed.
bool isPremiumAt(int? until, DateTime now) =>
    until != null && until > now.millisecondsSinceEpoch;

/// What to cache after the store confirms an active subscription.
int trustedUntil(DateTime now) => now.add(entitlementTrust).millisecondsSinceEpoch;

/// Whether the store is due to be asked again. Never checked is due.
bool dueForCheck(int? checkedAt, DateTime now) =>
    checkedAt == null ||
    now.millisecondsSinceEpoch - checkedAt >= entitlementRecheck.inMilliseconds;

/// Can one more document be saved?
bool canSaveDocument({required bool premium, required int liveDocuments}) =>
    premium || liveDocuments < freeTierDocumentLimit;

/// The "N documents left" line, or null when it should not show: premium
/// users, and free users still well clear of the limit.
int? documentsLeftToShow({required bool premium, required int liveDocuments}) {
  if (premium) return null;
  final left = freeTierDocumentLimit - liveDocuments;
  if (left > documentsLeftWarnAt || left < 0) return null;
  return left;
}
