// Brief computation and generation service (PBI-039a).
import 'package:intl/intl.dart';

import '../../../data/repositories/repositories.dart';
import '../../score/domain/life_score.dart' show ScoreWeights;
import 'brief_data.dart';

/// Brief consent enum.
enum BriefConsent {
  never,
  ask,
  always;

  static BriefConsent parse(String? value) {
    if (value == 'always') return BriefConsent.always;
    if (value == 'never') return BriefConsent.never;
    return BriefConsent.ask;
  }
}

/// Compute the brief data from the database.
Future<BriefData> computeBriefData({
  required Repositories repos,
  required DateTime now,
  required ScoreWeights weights,
}) async {
  final today = DateFormat('yyyy-MM-dd').format(now);
  final monthStart = DateFormat('yyyy-MM-01').format(now);

  // Tasks due today
  final tasks = await repos.tasks.watchAll().first;
  final todayTasks = tasks.where((t) {
    if (t.deletedAt != null || t.status != 'open') return false;
    if (t.dueAt == null) return false;
    final due = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
    return DateFormat('yyyy-MM-dd').format(due) == today;
  }).length;

  // Overdue payments
  final payments = await repos.payments.watchAll().first;
  final overdue = payments.where((p) {
    if (p.deletedAt != null) return false;
    if (p.status == 'paid' || p.status == 'skipped') return false;
    return p.dueDate.compareTo(today) < 0;
  }).length;

  // Expiring documents (30-day window)
  final docs = await repos.documents.watchAll().first;
  final expiringSoon = docs.where((d) {
    if (d.deletedAt != null || d.archivedAt != null) return false;
    if (d.expiryDate == null) return false;
    final expiry = DateTime.parse(d.expiryDate!);
    final daysLeft = expiry.difference(now).inDays;
    return daysLeft >= 0 && daysLeft <= 30;
  }).length;

  // Spending
  final expenses = await repos.expenses.watchAll().first;
  var spentToday = 0;
  var spentThisMonth = 0;
  for (final e in expenses) {
    if (e.deletedAt != null) continue;
    if (e.spentOn == today) spentToday += e.amountMinor;
    if (e.spentOn.compareTo(monthStart) >= 0) spentThisMonth += e.amountMinor;
  }

  // Budget from settings
  final settings = await repos.userSettings.watchAll().first;
  final salary = settings.isNotEmpty ? (settings.first.salaryMinor ?? 0) : 0;

  // Life Score - simplified computation
  final score = _computeSimpleScore(
    tasks: todayTasks,
    overdue: overdue,
    expiring: expiringSoon,
  );

  return BriefData(
    taskCount: todayTasks,
    overduePayments: overdue,
    expiringDocs: expiringSoon,
    spentToday: spentToday,
    spentThisMonth: spentThisMonth,
    monthlyBudget: salary,
    lifeScore: score,
    lifeScoreBand: BriefData.bandFromScore(score),
  );
}

int _computeSimpleScore({
  required int tasks,
  required int overdue,
  required int expiring,
}) {
  // Simple heuristic - start at 80, subtract for issues
  var score = 80;
  score -= (overdue * 10).clamp(0, 30);
  score -= (expiring * 5).clamp(0, 20);
  return score.clamp(0, 100);
}

/// Generate plain-text brief (fallback when AI unavailable).
String generatePlainTextBrief(BriefData data, {String language = 'en'}) {
  const currency = 'Rs'; // Would come from settings
  final spentMonth = (data.spentThisMonth / 100).toStringAsFixed(0);
  final budget = (data.monthlyBudget / 100).toStringAsFixed(0);

  if (language == 'ur') {
    return _urduBrief(data, currency, spentMonth, budget);
  }
  return _englishBrief(data, currency, spentMonth, budget);
}

String _englishBrief(
    BriefData data, String currency, String spentMonth, String budget) {
  final greeting = _greeting(data.lifeScoreBand);
  final parts = <String>[greeting];

  if (data.taskCount > 0) {
    parts.add(
        'You have ${data.taskCount} task${data.taskCount == 1 ? '' : 's'} today.');
  } else {
    parts.add('No tasks due today.');
  }

  if (data.overduePayments > 0) {
    parts.add(
        '${data.overduePayments} payment${data.overduePayments == 1 ? ' is' : 's are'} overdue.');
  }

  if (data.expiringDocs > 0) {
    parts.add(
        '${data.expiringDocs} document${data.expiringDocs == 1 ? '' : 's'} expire${data.expiringDocs == 1 ? 's' : ''} soon.');
  }

  if (data.monthlyBudget > 0) {
    final pct = ((data.spentThisMonth / data.monthlyBudget) * 100).round();
    parts.add('Spent $currency $spentMonth this month ($pct% of budget).');
  } else if (data.spentThisMonth > 0) {
    parts.add('Spent $currency $spentMonth this month.');
  }

  parts.add('Life Score: ${data.lifeScore}.');

  return parts.join(' ');
}

String _urduBrief(
    BriefData data, String currency, String spentMonth, String budget) {
  final parts = <String>[];

  if (data.lifeScoreBand == 'triage') {
    parts.add('آج کا دن مشکل ہے۔');
  } else if (data.lifeScoreBand == 'excellent') {
    parts.add('صبح بخیر! آج اچھا دن ہے۔');
  } else {
    parts.add('صبح بخیر۔');
  }

  parts.add('آج ${data.taskCount} کام ہیں۔');

  if (data.overduePayments > 0) {
    parts.add('${data.overduePayments} ادائیگیاں بقایا ہیں۔');
  }

  parts.add('لائف سکور: ${data.lifeScore}۔');

  return parts.join(' ');
}

String _greeting(String band) => switch (band) {
      'triage' => 'Heavy week ahead.',
      'excellent' => 'Great day ahead!',
      _ => 'Good morning.',
    };

/// Generate AI brief (returns null on failure).
Future<String?> generateAiBrief({
  required BriefData data,
  required dynamic settings,
  required bool isMorning,
}) async {
  // AI brief generation not implemented in this version
  // Returns null to fallback to plain text
  return null;
}
