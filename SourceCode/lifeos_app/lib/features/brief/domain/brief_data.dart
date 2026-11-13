// Daily Brief data model (PBI-039a).

/// The seven fields sent to the LLM — no sensitive data.
class BriefData {
  const BriefData({
    required this.taskCount,
    required this.overduePayments,
    required this.expiringDocs,
    required this.spentToday,
    required this.spentThisMonth,
    required this.monthlyBudget,
    required this.lifeScore,
    required this.lifeScoreBand,
  });

  /// Tasks due today
  final int taskCount;

  /// Payments overdue (past due date, not paid)
  final int overduePayments;

  /// Documents expiring in next 30 days
  final int expiringDocs;

  /// Amount spent today (minor units)
  final int spentToday;

  /// Amount spent this month (minor units)
  final int spentThisMonth;

  /// Monthly budget from forecast (minor units)
  final int monthlyBudget;

  /// Life Score 0-100
  final int lifeScore;

  /// triage (<40), steady (40-70), excellent (70+)
  final String lifeScoreBand;

  /// Percentage of budget used this month.
  int get budgetUsedPercent {
    if (monthlyBudget <= 0) return 0;
    return ((spentThisMonth / monthlyBudget) * 100).round().clamp(0, 999);
  }

  /// Whether budget usage is critical (>90%).
  bool get isBudgetCritical => budgetUsedPercent > 90;

  /// Whether today is a clear day (no urgent items).
  bool get isClearDay =>
      taskCount == 0 && overduePayments == 0 && expiringDocs == 0;

  /// Whether there are urgent items needing attention.
  bool get hasUrgentItems => overduePayments > 0 || expiringDocs > 0;

  Map<String, dynamic> toJson() => {
        'task_count': taskCount,
        'overdue_payments': overduePayments,
        'expiring_docs': expiringDocs,
        'spent_today': spentToday,
        'spent_this_month': spentThisMonth,
        'monthly_budget': monthlyBudget,
        'life_score': lifeScore,
        'life_score_band': lifeScoreBand,
      };

  static String bandFromScore(int score) {
    if (score < 40) return 'triage';
    if (score < 70) return 'steady';
    return 'excellent';
  }
}

/// The response from LLM or plain-text generation.
class BriefResponse {
  const BriefResponse({
    required this.text,
    required this.tone,
    required this.isAi,
  });

  final String text;
  final String tone; // triage|steady|excellent
  final bool isAi;
}
