// LLM prompt for natural-language brief generation (PBI-039a).
//
// The prompt is designed to be conversational and warm while staying
// within safe boundaries — only summary metrics, never PII or amounts.

/// System prompt for the brief LLM call.
const briefSystemPrompt = '''
You are a friendly personal assistant helping someone start their day.
Generate a warm, conversational morning brief in 2-3 sentences based on
the metrics provided. Keep it encouraging and actionable.

Guidelines:
- Be warm and supportive, like a helpful friend
- Mention only the most important 1-2 things to focus on
- If everything looks good, celebrate that
- Use natural language, not bullet points
- Keep it under 50 words
- Never mention specific amounts, names, or sensitive details
- Focus on counts and priorities, not specifics
''';

/// Builds the user prompt with the 7 safe metrics.
String buildBriefUserPrompt({
  required int taskCount,
  required int overduePayments,
  required int expiringDocs,
  required int budgetUsedPercent,
  required int lifeScore,
  required String lifeScoreBand,
  required bool isMorning,
}) {
  final timeOfDay = isMorning ? 'morning' : 'day';
  return '''
Generate a brief $timeOfDay update for this person:

- Tasks due today: $taskCount
- Overdue payments: $overduePayments
- Documents expiring soon: $expiringDocs
- Budget used this month: $budgetUsedPercent%
- Life Score: $lifeScore/100 ($lifeScoreBand)

Remember: Be warm and brief. Focus on what matters most. No specific names or amounts.
''';
}

/// Builds the request body for the OpenAI-compatible API.
Map<String, Object?> buildBriefRequestBody({
  required String model,
  required int taskCount,
  required int overduePayments,
  required int expiringDocs,
  required int budgetUsedPercent,
  required int lifeScore,
  required String lifeScoreBand,
  required bool isMorning,
}) => {
  'model': model,
  'max_tokens': 100,
  'temperature': 0.7,
  'messages': [
    {'role': 'system', 'content': briefSystemPrompt},
    {
      'role': 'user',
      'content': buildBriefUserPrompt(
        taskCount: taskCount,
        overduePayments: overduePayments,
        expiringDocs: expiringDocs,
        budgetUsedPercent: budgetUsedPercent,
        lifeScore: lifeScore,
        lifeScoreBand: lifeScoreBand,
        isMorning: isMorning,
      ),
    },
  ],
};

/// Parses the assistant's message from an OpenAI-compatible response.
String? parseBriefResponse(String responseBody) {
  try {
    // Simple JSON parsing without importing dart:convert here
    // The actual parsing happens in the service layer
    return responseBody;
  } on Object {
    return null;
  }
}
