// Bill pattern learning (PBI-014) — pure, no database, no Flutter.
import 'dart:math' as math;

/// Proposals need at least this confidence (PBI-014).
const proposalThreshold = 0.7;

/// Arrival days may spread at most this many days (population σ).
const maxArrivalSigma = 4.0;

/// A bill counts as a spike above this multiple of the usual amount.
const spikeFactor = 2;

/// How many previous bills the spike check averages.
const spikeWindow = 6;

/// One scanned bill, as the learner sees it.
class BillObservation {
  const BillObservation({
    required this.documentId,
    required this.issuer,
    required this.ref,
    required this.month,
    required this.arrivalDay,
    this.amountMinor,
  });

  final String documentId;
  final String issuer;

  /// Reference / meter number; '' when the bill had none.
  final String ref;

  /// Billing month (first of month).
  final DateTime month;

  /// Day of month the bill arrived (was scanned).
  final int arrivalDay;
  final int? amountMinor;

  String get key => '$issuer|$ref';
}

/// A regular bill worth proposing as a rule.
class PatternCandidate {
  const PatternCandidate({
    required this.issuer,
    required this.ref,
    required this.cycles,
    required this.meanDay,
    required this.sigma,
    required this.windowFrom,
    required this.windowTo,
    required this.confidence,
    this.amountAvgMinor,
    this.amountMinMinor,
    this.amountMaxMinor,
  });

  final String issuer;
  final String ref;

  /// Consecutive months in the latest run.
  final int cycles;
  final double meanDay;
  final double sigma;
  final int windowFrom;
  final int windowTo;
  final double confidence;
  final int? amountAvgMinor;
  final int? amountMinMinor;
  final int? amountMaxMinor;

  /// The predicted arrival day (rule `due_day`).
  int get predictedDay => meanDay.round().clamp(1, 31);

  bool get proposable => confidence >= proposalThreshold;
}

/// Confidence from cycles observed and regularity: 0.75 / 0.85 / 0.95 for
/// 2 / 3 / ≥4 cycles, minus 0.03 per day of spread. Never below 0.
double patternConfidence(int cycles, double sigma) {
  if (cycles < 2) return 0;
  final base = switch (cycles) {
    2 => 0.75,
    3 => 0.85,
    _ => 0.95,
  };
  return math.max(0, base - 0.03 * sigma);
}

int _monthIndex(DateTime m) => m.year * 12 + m.month - 1;

/// The latest run of consecutive billing months for one issuer + ref.
/// Several scans for one month keep the newest (last in [bills]).
List<BillObservation> latestRun(List<BillObservation> bills) {
  final byMonth = <int, BillObservation>{};
  for (final b in bills) {
    byMonth[_monthIndex(b.month)] = b;
  }
  final months = byMonth.keys.toList()..sort();
  if (months.isEmpty) return const [];
  final run = <BillObservation>[byMonth[months.last]!];
  for (var i = months.length - 2; i >= 0; i--) {
    if (months[i] != months[i + 1] - 1) break;
    run.insert(0, byMonth[months[i]]!);
  }
  return run;
}

/// Detects the pattern for bills from one issuer + ref, or null when they
/// are too few or too irregular (AC1, AC2).
PatternCandidate? detectPattern(List<BillObservation> bills) {
  final run = latestRun(bills);
  if (run.length < 2) return null;
  final days = [for (final b in run) b.arrivalDay.toDouble()];
  final mean = days.reduce((a, b) => a + b) / days.length;
  final variance =
      days.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
      days.length;
  final sigma = math.sqrt(variance);
  if (sigma > maxArrivalSigma) return null;

  final amounts = [
    for (final b in run)
      if (b.amountMinor != null) b.amountMinor!,
  ];
  final avg = amounts.isEmpty
      ? null
      : (amounts.reduce((a, b) => a + b) / amounts.length).round();
  return PatternCandidate(
    issuer: run.first.issuer,
    ref: run.first.ref,
    cycles: run.length,
    meanDay: mean,
    sigma: sigma,
    windowFrom: (mean - sigma).round().clamp(1, 31),
    windowTo: (mean + sigma).round().clamp(1, 31),
    confidence: patternConfidence(run.length, sigma),
    amountAvgMinor: avg,
    amountMinMinor: amounts.isEmpty
        ? null
        : _roundDown(amounts.reduce(math.min)),
    amountMaxMinor: amounts.isEmpty ? null : _roundUp(amounts.reduce(math.max)),
  );
}

/// One candidate per issuer + ref in [bills] (AC4: two meters are two
/// patterns). Only proposable ones are returned.
List<PatternCandidate> detectPatterns(List<BillObservation> bills) {
  final groups = <String, List<BillObservation>>{};
  for (final b in bills) {
    groups.putIfAbsent(b.key, () => []).add(b);
  }
  return [for (final g in groups.values) ?detectPattern(g)]
      .where((c) => c.proposable)
      .toList();
}

/// Rs 500 steps for the "~Rs 4,000–6,000" range (minor units).
const _rangeStep = 50000;
int _roundDown(int minor) => (minor ~/ _rangeStep) * _rangeStep;
int _roundUp(int minor) =>
    ((minor + _rangeStep - 1) ~/ _rangeStep) * _rangeStep;

/// Whether [amountMinor] is more than 2× the average of [previous] (AC6).
/// Needs at least one earlier bill.
bool isSpike(int amountMinor, List<int> previous) {
  if (previous.isEmpty) return false;
  final recent = previous.length > spikeWindow
      ? previous.sublist(previous.length - spikeWindow)
      : previous;
  final avg = recent.reduce((a, b) => a + b) / recent.length;
  return amountMinor > spikeFactor * avg;
}

/// Average of the last [spikeWindow] amounts (for "vs usual Rs Y").
int usualAmount(List<int> previous) {
  final recent = previous.length > spikeWindow
      ? previous.sublist(previous.length - spikeWindow)
      : previous;
  return (recent.reduce((a, b) => a + b) / recent.length).round();
}

/// What kind of bill an issuer sends: electricity, gas, water, internet or
/// mobile (used in titles and the M1 prompt).
String billLabel(String issuer) => switch (issuer) {
  'K-Electric' || 'LESCO' || 'IESCO' || 'MEPCO' || 'PESCO' => 'electricity',
  'SSGC' || 'SNGPL' => 'gas',
  'WASA' => 'water',
  'PTCL' || 'StormFiber' || 'Nayatel' => 'internet',
  'Jazz' || 'Zong' || 'Telenor' || 'Ufone' => 'mobile',
  _ => 'utility',
};

/// Expense category for an issuer's bills.
String billCategoryKey(String issuer) => switch (billLabel(issuer)) {
  'internet' => 'internet',
  'mobile' => 'mobile',
  _ => 'utilities',
};

String capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Missed month (PBI-014): the predicted bill still hasn't come more than
/// 3 days after the arrival window ended.
bool isBillLate({
  required DateTime predictedArrival,
  required int windowTo,
  required DateTime today,
}) {
  final windowEnd = DateTime(
    predictedArrival.year,
    predictedArrival.month,
    math.max(windowTo, predictedArrival.day),
  );
  final day = DateTime(today.year, today.month, today.day);
  return day.isAfter(
    DateTime(windowEnd.year, windowEnd.month, windowEnd.day + 3),
  );
}
