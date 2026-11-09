// Home dashboard rules (PBI-021) — pure, no database; words via l10nNow.
import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';
import '../../money/domain/money_rules.dart' show parseIsoDate;

/// Needs Attention shows at most this many items before "See all".
const attentionCap = 3;

/// Documents within this many days of expiry need attention.
const expiringWithinDays = 30;

enum AttentionKind { payment, document }

/// One thing that needs the user: a payment due soon or past due, or a
/// document about to expire.
class AttentionItem {
  const AttentionItem._({
    required this.kind,
    required this.id,
    required this.title,
    required this.daysLeft,
    this.payment,
    this.document,
  });

  factory AttentionItem.payment(Payment p, int daysLeft) => AttentionItem._(
    kind: AttentionKind.payment,
    id: p.id,
    title: p.title,
    daysLeft: daysLeft,
    payment: p,
  );

  factory AttentionItem.document(Document d, int daysLeft) => AttentionItem._(
    kind: AttentionKind.document,
    id: d.id,
    title: d.title,
    daysLeft: daysLeft,
    document: d,
  );

  final AttentionKind kind;
  final String id;
  final String title;

  /// Days until the deadline; negative once it has passed.
  final int daysLeft;
  final Payment? payment;
  final Document? document;

  /// 🔴 past due or due today/tomorrow, 🟠 otherwise — always with words.
  bool get urgent => daysLeft <= 1;

  /// "due tomorrow · Rs 4,850" style detail, without the amount.
  String get when {
    final l = l10nNow;
    final pay = kind == AttentionKind.payment;
    if (daysLeft < 0) {
      final n = -daysLeft;
      return pay ? l.hmWasDueAgo(n) : l.hmExpiredAgo(n);
    }
    if (daysLeft == 0) return pay ? l.hmDueToday : l.hmExpiresToday;
    if (daysLeft == 1) return pay ? l.hmDueTomorrow : l.hmExpiresTomorrow;
    return pay ? l.hmDueIn('$daysLeft') : l.hmExpiresIn('$daysLeft');
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Everything that needs attention, most urgent first (AC1): unpaid
/// payments due by tomorrow (overdue included) and live documents expiring
/// within 30 days (expired included). Ordered by days left; on a tie,
/// payments come first.
List<AttentionItem> attentionItems({
  required List<Payment> payments,
  required List<Document> documents,
  required DateTime now,
}) {
  final today = _day(now);
  int daysTo(String iso) => parseIsoDate(iso).difference(today).inDays;
  final items = <AttentionItem>[
    for (final p in payments)
      if (p.deletedAt == null &&
          p.status != 'paid' &&
          p.status != 'skipped' &&
          daysTo(p.dueDate) <= 1)
        AttentionItem.payment(p, daysTo(p.dueDate)),
    for (final d in documents)
      if (d.deletedAt == null &&
          d.archivedAt == null &&
          d.expiryDate != null &&
          daysTo(d.expiryDate!) <= expiringWithinDays)
        AttentionItem.document(d, daysTo(d.expiryDate!)),
  ];
  items.sort((a, b) {
    final byDays = a.daysLeft.compareTo(b.daysLeft);
    if (byDays != 0) return byDays;
    return a.kind.index.compareTo(b.kind.index); // payments first
  });
  return items;
}

/// Monday–Sunday of [now]'s week.
({DateTime from, DateTime to}) weekOf(DateTime now) {
  final today = _day(now);
  final monday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return (
    from: monday,
    to: DateTime(monday.year, monday.month, monday.day + 6),
  );
}

/// Sum of unpaid payments due Monday–Sunday of this week (AC3). Unknown
/// amounts are left out.
int weekPaymentsMinor(List<Payment> payments, DateTime now) {
  final w = weekOf(now);
  var sum = 0;
  for (final p in payments) {
    if (p.deletedAt != null || p.status == 'paid' || p.status == 'skipped') {
      continue;
    }
    final due = parseIsoDate(p.dueDate);
    if (due.isBefore(w.from) || due.isAfter(w.to)) continue;
    sum += p.amountMinor ?? 0;
  }
  return sum;
}

/// Time-of-day greeting — "Good morning, Owais ☀️", just "Good morning ☀️"
/// while the profile is still "Me". Neutral by design (PBI-035): default
/// strings carry no religious or cultural wording in any language.
String greeting(Person? self, DateTime now) {
  final l = l10nNow;
  final name = self?.name.trim();
  final named = name != null && name.isNotEmpty && name != 'Me';
  return switch (now.hour) {
    >= 5 && < 12 => named ? l.hmGreetMorningName(name) : l.hmGreetMorning,
    >= 12 && < 17 => named ? l.hmGreetAfternoonName(name) : l.hmGreetAfternoon,
    >= 17 && < 21 => named ? l.hmGreetEveningName(name) : l.hmGreetEvening,
    _ => named ? l.hmGreetNightName(name) : l.hmGreetNight,
  };
}
