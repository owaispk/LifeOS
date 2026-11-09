// Daily Life Score v1 (PBI-020) — pure, no database; words via l10nNow.
import 'dart:convert';

import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart' show shortMonth;
import '../../money/domain/money_rules.dart' show parseIsoDate;

/// Score components (features spec §9.1).
enum ScoreComponent { tasks, payments, documents, health, people, balance }

/// Components that have no module yet in v1: their weight is redistributed
/// proportionally, so unused domains never reduce the score.
const unusedInV1 = {
  ScoreComponent.health,
  ScoreComponent.people,
  ScoreComponent.balance,
};

/// Components the v1 engine can measure. Anything else is redistributed
/// even if a caller marks it in use: no module, no penalty.
const measuredInV1 = {
  ScoreComponent.tasks,
  ScoreComponent.payments,
  ScoreComponent.documents,
};

/// A document is in the danger window this many days before expiry.
const dangerWindowDays = 30;

/// Each overdue payment / endangered document costs this share of its
/// component (3 items empty it).
const itemsToEmpty = 3;

/// Component weights in percent, version-pinned. Mirrors the shipped
/// `assets/score_weights.json` (a test keeps them equal).
class ScoreWeights {
  const ScoreWeights({required this.version, required this.weights});

  factory ScoreWeights.fromJson(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final w = m['weights'] as Map<String, dynamic>;
    return ScoreWeights(
      version: m['version'] as int,
      weights: {
        for (final c in ScoreComponent.values) c: (w[c.name] as num).toDouble(),
      },
    );
  }

  static const v1 = ScoreWeights(
    version: 1,
    weights: {
      ScoreComponent.tasks: 30,
      ScoreComponent.payments: 25,
      ScoreComponent.documents: 15,
      ScoreComponent.health: 15,
      ScoreComponent.people: 10,
      ScoreComponent.balance: 5,
    },
  );

  final int version;
  final Map<ScoreComponent, double> weights;

  /// Weights of the active components, scaled to add up to 100.
  Map<ScoreComponent, double> effective(Set<ScoreComponent> unused) {
    final active = {
      for (final e in weights.entries)
        if (!unused.contains(e.key)) e.key: e.value,
    };
    final sum = active.values.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return const {};
    return {for (final e in active.entries) e.key: e.value * 100 / sum};
  }
}

/// What pulls the score down.
enum DragKind { task, overduePayment, expiringDocument }

/// One item dragging the score down, with what it costs (negative points).
class Drag {
  const Drag({
    required this.kind,
    required this.id,
    required this.title,
    required this.points,
    this.detail,
  });

  final DragKind kind;

  /// The real task / payment / document id (AC3).
  final String id;
  final String title;

  /// Negative, rounded to 0.1.
  final double points;

  /// Friendly context: "Due 2 Nov", "Expires in 12 days".
  final String? detail;

  String get kindKey => switch (kind) {
    DragKind.task => 'task',
    DragKind.overduePayment => 'overdue_payment',
    DragKind.expiringDocument => 'expiring_document',
  };

  Map<String, Object?> toJson() => {
    'kind': kindKey,
    'id': id,
    'title': title,
    'points': points,
  };
}

/// One component's share of today's score.
class ComponentScore {
  const ComponentScore({
    required this.component,
    required this.weight,
    required this.ratio,
  });

  final ScoreComponent component;

  /// Effective weight after redistribution (percent of 100).
  final double weight;

  /// 0..1: how much of the component is earned.
  final double ratio;

  double get contribution => weight * ratio;
}

class LifeScore {
  const LifeScore({
    required this.score,
    required this.components,
    required this.drags,
  });

  /// 0–100.
  final int score;
  final List<ComponentScore> components;

  /// Most costly first.
  final List<Drag> drags;

  /// Below 40 the detail screen switches to triage mode.
  bool get triage => score < 40;

  String componentsJson() => jsonEncode({
    for (final c in components)
      c.component.name: {
        'weight': _r1(c.weight),
        'ratio': _r2(c.ratio),
        'points': _r1(c.contribution),
      },
  });

  String dragsJson() => jsonEncode([for (final d in drags) d.toJson()]);
}

double _r1(double v) => (v * 10).round() / 10;
double _r2(double v) => (v * 100).round() / 100;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Computes today's Life Score from live data (PBI-020).
///
/// - Tasks: completion of the tasks due yesterday; ATC tasks count double.
///   No tasks due yesterday → full marks.
/// - Payments: each unpaid payment past its due date costs ⅓ of the
///   component (capped; with more than 3 each costs component ÷ n).
/// - Documents: same, for live documents expiring within 30 days or
///   already expired.
LifeScore computeLifeScore({
  required List<Task> tasks,
  required List<Payment> payments,
  required List<Document> documents,
  required DateTime now,
  ScoreWeights weights = ScoreWeights.v1,
  Set<ScoreComponent> unused = unusedInV1,
}) {
  final w = weights.effective({
    ...unused,
    ...ScoreComponent.values.where((c) => !measuredInV1.contains(c)),
  });
  final today = _day(now);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final drags = <Drag>[];
  final components = <ComponentScore>[];

  // ── Tasks ──
  final taskWeight = w[ScoreComponent.tasks];
  if (taskWeight != null) {
    final due = tasks.where((t) {
      if (t.deletedAt != null || t.dueAt == null) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
      return !d.isBefore(yesterday) && d.isBefore(today);
    }).toList();
    int weightOf(Task t) => t.atcRuleId == null ? 1 : 2;
    final total = due.fold<int>(0, (s, t) => s + weightOf(t));
    var done = 0;
    for (final t in due) {
      if (t.status == 'done') {
        done += weightOf(t);
      } else {
        drags.add(
          Drag(
            kind: DragKind.task,
            id: t.id,
            title: t.title,
            points: -_r1(taskWeight * weightOf(t) / total),
            detail: l10nNow.scStillOpen,
          ),
        );
      }
    }
    components.add(
      ComponentScore(
        component: ScoreComponent.tasks,
        weight: taskWeight,
        ratio: total == 0 ? 1 : done / total,
      ),
    );
  }

  // ── Payments ──
  final payWeight = w[ScoreComponent.payments];
  if (payWeight != null) {
    final overdue =
        payments
            .where(
              (p) =>
                  p.deletedAt == null &&
                  p.status != 'paid' &&
                  p.status != 'skipped' &&
                  parseIsoDate(p.dueDate).isBefore(today),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final per = _perItem(payWeight, overdue.length);
    for (final p in overdue) {
      final d = parseIsoDate(p.dueDate);
      drags.add(
        Drag(
          kind: DragKind.overduePayment,
          id: p.id,
          title: p.title,
          points: -_r1(per),
          detail: l10nNow.scWasDue('${d.day} ${shortMonth(d)}'),
        ),
      );
    }
    components.add(
      ComponentScore(
        component: ScoreComponent.payments,
        weight: payWeight,
        ratio: _ratio(overdue.length),
      ),
    );
  }

  // ── Documents ──
  final docWeight = w[ScoreComponent.documents];
  if (docWeight != null) {
    final limit = DateTime(
      today.year,
      today.month,
      today.day + dangerWindowDays,
    );
    final danger =
        documents
            .where(
              (d) =>
                  d.deletedAt == null &&
                  d.archivedAt == null &&
                  d.expiryDate != null &&
                  !parseIsoDate(d.expiryDate!).isAfter(limit),
            )
            .toList()
          ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    final per = _perItem(docWeight, danger.length);
    for (final d in danger) {
      final days = parseIsoDate(d.expiryDate!).difference(today).inDays;
      drags.add(
        Drag(
          kind: DragKind.expiringDocument,
          id: d.id,
          title: d.title,
          points: -_r1(per),
          detail: days < 0
              ? l10nNow.scExpiredAgo(-days)
              : days == 0
              ? l10nNow.scExpiresToday
              : l10nNow.scExpiresIn(days),
        ),
      );
    }
    components.add(
      ComponentScore(
        component: ScoreComponent.documents,
        weight: docWeight,
        ratio: _ratio(danger.length),
      ),
    );
  }

  final sum = components.fold<double>(0, (s, c) => s + c.contribution);
  drags.sort((a, b) => a.points.compareTo(b.points)); // most costly first
  return LifeScore(
    score: sum.round().clamp(0, 100),
    components: components,
    drags: drags,
  );
}

double _perItem(double weight, int n) =>
    n == 0 ? 0 : (n <= itemsToEmpty ? weight / itemsToEmpty : weight / n);

double _ratio(int n) => n >= itemsToEmpty ? 0 : 1 - n / itemsToEmpty;

/// The ring's status: red < 40, amber 40–69, green ≥ 70 — always paired
/// with words, never colour alone.
String scoreLabel(int score) => score < 40
    ? l10nNow.scHeavyWeek
    : score < 70
    ? l10nNow.scFewThings
    : l10nNow.scDoingWell;

String componentLabel(ScoreComponent c) => switch (c) {
  ScoreComponent.tasks => l10nNow.scCompTasks,
  ScoreComponent.payments => l10nNow.scCompPayments,
  ScoreComponent.documents => l10nNow.scCompDocuments,
  ScoreComponent.health => l10nNow.scCompHealth,
  ScoreComponent.people => l10nNow.scCompPeople,
  ScoreComponent.balance => l10nNow.scCompBalance,
};
