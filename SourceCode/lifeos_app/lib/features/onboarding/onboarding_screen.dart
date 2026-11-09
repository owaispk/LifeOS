import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repositories.dart';
import '../../shared/format.dart';
import '../atc/atc_providers.dart';
import '../atc/data/atc_service.dart';
import '../capture/capture_entry.dart';
import '../money/domain/forecast.dart';
import '../money/domain/money_rules.dart' show addMonths, monthStart;
import '../reminders/reminder_providers.dart';
import '../settings/data/data_service.dart' show onboardingDoneKey;

/// Whether onboarding is finished or skipped; null while loading (and on
/// the web preview, which never redirects).
final onboardingDoneProvider = StreamProvider<bool>((ref) {
  final db = ref.watch(repositoriesProvider).db;
  return (db.select(db.appMeta)..where((m) => m.key.equals(onboardingDoneKey)))
      .watch()
      .map((rows) => rows.isNotEmpty);
});

Future<void> markOnboardingDone(AppDatabase db, {String? role}) async {
  await db
      .into(db.appMeta)
      .insertOnConflictUpdate(
        AppMetaCompanion.insert(key: onboardingDoneKey, value: '1'),
      );
  if (role != null) {
    await db
        .into(db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: 'role', value: role),
        );
  }
}

enum Role { student, professional, parent, business, justMe }

/// One "What do you pay every month?" chip.
class PayChip {
  const PayChip(
    this.key,
    this.emoji,
    this.categoryKey, {
    this.optional = false,
  });
  final String key;
  final String emoji;
  final String categoryKey;

  /// Bills whose amount changes: the amount may be left empty.
  final bool optional;
}

const payChips = [
  PayChip('rent', '🏠', 'rent'),
  PayChip('electricity', '💡', 'utilities', optional: true),
  PayChip('gas', '🔥', 'utilities', optional: true),
  PayChip('internet', '🌐', 'internet'),
  PayChip('fee', '🎓', 'fees'),
  PayChip('mobile', '📱', 'mobile'),
  PayChip('installment', '📆', 'installment'),
  PayChip('custom', '✳️', 'other', optional: true),
];

/// The role tunes which chips come first (PBI-022).
List<PayChip> chipsFor(Role? role) {
  final first = switch (role) {
    Role.parent => const ['fee', 'rent'],
    Role.student => const ['mobile', 'internet'],
    Role.business => const ['rent', 'electricity', 'internet'],
    _ => const <String>[],
  };
  return [
    for (final k in first) payChips.firstWhere((c) => c.key == k),
    for (final c in payChips)
      if (!first.contains(c.key)) c,
  ];
}

String chipLabel(AppLocalizations l, PayChip c) => switch (c.key) {
  'rent' => l.payRent,
  'electricity' => l.payElectricity,
  'gas' => l.payGas,
  'internet' => l.payInternet,
  'fee' => l.paySchoolFee,
  'mobile' => l.payMobile,
  'installment' => l.payInstallment,
  _ => l.payCustom,
};

/// 0.2 Onboarding (PBI-022): role → first scan → monthly payments → done.
/// No account; steps 2–4 can be skipped.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  Role? _role;

  Future<void> _finish() async {
    await markOnboardingDone(
      ref.read(repositoriesProvider).db,
      role: _role?.name,
    );
    if (mounted) context.go('/home');
  }

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l.obWelcome),
        actions: [
          if (_step > 0 && _step < 3)
            TextButton(
              key: const ValueKey('ob-skip'),
              onPressed: _next,
              child: Text(l.skip),
            ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_step) {
            0 => _RoleStep(
              key: const ValueKey('ob-step-role'),
              onPicked: (r) {
                _role = r;
                _next();
              },
            ),
            1 => _ScanStep(key: const ValueKey('ob-step-scan'), onDone: _next),
            2 => _PayStep(
              key: const ValueKey('ob-step-pay'),
              chips: chipsFor(_role),
              onNext: _next,
            ),
            _ => _DoneStep(
              key: const ValueKey('ob-step-done'),
              onDone: _finish,
            ),
          },
        ),
      ),
    );
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({super.key, required this.onPicked});
  final ValueChanged<Role> onPicked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final roles = [
      (Role.student, '🎒', l.roleStudent),
      (Role.professional, '💼', l.roleProfessional),
      (Role.parent, '👨‍👩‍👧', l.roleParent),
      (Role.business, '🏪', l.roleBusiness),
      (Role.justMe, '🙂', l.roleJustMe),
    ];
    return ListView(
      padding: EdgeInsets.all(Tokens.spaceM),
      children: [
        Text(l.obRoleQ, style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: Tokens.spaceM),
        for (final (role, emoji, label) in roles)
          Card(
            child: ListTile(
              key: ValueKey('ob-role-${role.name}'),
              leading: Text(emoji, style: const TextStyle(fontSize: 26)),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPicked(role),
            ),
          ),
      ],
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(Tokens.spaceL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📸', style: TextStyle(fontSize: 64)),
          SizedBox(height: Tokens.spaceM),
          Text(l.obScanTitle, style: theme.textTheme.headlineSmall),
          SizedBox(height: Tokens.spaceS),
          Text(l.obScanBody, textAlign: TextAlign.center),
          SizedBox(height: Tokens.spaceL),
          // The camera permission comes from the scanner itself — only
          // after this tap (AC4).
          FilledButton(
            key: const ValueKey('ob-scan'),
            onPressed: () async {
              await startScan(context);
              onDone();
            },
            child: Text(l.obScanNow),
          ),
          TextButton(onPressed: onDone, child: Text(l.skip)),
        ],
      ),
    );
  }
}

class _PayStep extends ConsumerStatefulWidget {
  const _PayStep({super.key, required this.chips, required this.onNext});
  final List<PayChip> chips;
  final VoidCallback onNext;

  @override
  ConsumerState<_PayStep> createState() => _PayStepState();
}

class _PayStepState extends ConsumerState<_PayStep> {
  String? _open;
  final _on = <String>{};
  final _amount = TextEditingController();
  final _name = TextEditingController();
  int _day = 1;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _turnOn(PayChip c) async {
    final l = context.l10n;
    final amount = Money.parseMinor(_amount.text);
    if (!c.optional && (amount == null || amount <= 0)) return;
    try {
      await ref
          .read(atcServiceProvider)
          .createRule(
            RuleInput(
              name: c.key == 'custom' && _name.text.trim().isNotEmpty
                  ? _name.text.trim()
                  : chipLabel(l, c),
              categoryKey: c.categoryKey,
              dueDay: _day,
              amountMinor: amount,
            ),
          );
      setState(() {
        _on.add(c.key);
        _open = null;
        _error = null;
      });
    } on FreeTierLimitException {
      setState(() => _error = l.freeLimitReached);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.all(Tokens.spaceM),
      children: [
        Text(l.obPayTitle, style: theme.textTheme.headlineSmall),
        SizedBox(height: Tokens.spaceXs),
        Text(l.obPayBody),
        SizedBox(height: Tokens.spaceM),
        Wrap(
          spacing: Tokens.spaceS,
          runSpacing: Tokens.spaceS,
          children: [
            for (final c in widget.chips)
              FilterChip(
                key: ValueKey('ob-chip-${c.key}'),
                avatar: Text(c.emoji),
                label: Text(chipLabel(l, c)),
                selected: _on.contains(c.key) || _open == c.key,
                onSelected: _on.contains(c.key)
                    ? null
                    : (_) => setState(() {
                        _open = c.key;
                        _amount.clear();
                        _name.clear();
                        _day = 1;
                      }),
              ),
          ],
        ),
        if (_open != null) ...[
          SizedBox(height: Tokens.spaceM),
          _chipForm(context, payChips.firstWhere((c) => c.key == _open)),
        ],
        if (_on.isNotEmpty) ...[
          SizedBox(height: Tokens.spaceM),
          for (final k in _on)
            ListTile(
              key: ValueKey('ob-on-$k'),
              dense: true,
              title: Text(chipLabel(l, payChips.firstWhere((c) => c.key == k))),
              trailing: Text(l.autoReminderOn),
            ),
        ],
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(top: Tokens.spaceS),
            child: Text(
              _error!,
              key: const ValueKey('ob-limit'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        SizedBox(height: Tokens.spaceL),
        FilledButton(
          key: const ValueKey('ob-next'),
          onPressed: widget.onNext,
          child: Text(l.next),
        ),
      ],
    );
  }

  Widget _chipForm(BuildContext context, PayChip c) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Tokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.key == 'custom')
              TextField(
                key: const ValueKey('ob-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l.name),
              ),
            TextField(
              key: const ValueKey('ob-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l.amount,
                prefixText: Money.prefix,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: Tokens.spaceS),
            Row(
              children: [
                Expanded(child: Text(l.dayOfMonth)),
                DropdownButton<int>(
                  key: const ValueKey('ob-day'),
                  value: _day,
                  onChanged: (v) => setState(() => _day = v ?? 1),
                  items: [
                    for (var d = 1; d <= 31; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                ),
              ],
            ),
            SizedBox(height: Tokens.spaceS),
            FilledButton.tonal(
              key: const ValueKey('ob-turn-on'),
              onPressed: c.optional || (Money.parseMinor(_amount.text) ?? 0) > 0
                  ? () => _turnOn(c)
                  : null,
              child: Text(l.turnOn),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneStep extends ConsumerStatefulWidget {
  const _DoneStep({super.key, required this.onDone});
  final Future<void> Function() onDone;

  @override
  ConsumerState<_DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends ConsumerState<_DoneStep> {
  @override
  void initState() {
    super.initState();
    // The notification permission is asked here, in context (AC4).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(notificationGatewayProvider).requestPermission(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    // The first full month ahead: every monthly payment falls in it once,
    // so its total equals the amounts just entered (AC3).
    final month = addMonths(monthStart(now), 1);
    final f = forecastFor(
      month,
      rules: ref.watch(atcRulesProvider).value ?? const <AtcRule>[],
      payments: ref.watch(allPaymentsProvider).value ?? const <Payment>[],
      now: now,
    );
    return Padding(
      padding: EdgeInsets.all(Tokens.spaceL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          SizedBox(height: Tokens.spaceM),
          Text(l.obDoneTitle, style: theme.textTheme.headlineSmall),
          SizedBox(height: Tokens.spaceM),
          Text(
            f.totalMinor == 0
                ? l.obForecastNone
                : l.obForecast(
                    formatMonth(month).split(' ').first,
                    Money.format(f.totalMinor),
                  ),
            key: const ValueKey('ob-forecast'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: Tokens.spaceS),
          Text(l.obNotifAsk, textAlign: TextAlign.center),
          SizedBox(height: Tokens.spaceL),
          FilledButton(
            key: const ValueKey('ob-finish'),
            onPressed: widget.onDone,
            child: Text(l.obSeeDashboard),
          ),
        ],
      ),
    );
  }
}

/// For tests and "Delete all local data": whether onboarding should show.
Future<bool> onboardingDone(AppDatabase db) async =>
    (await (db.select(
      db.appMeta,
    )..where((m) => m.key.equals(onboardingDoneKey))).getSingleOrNull()) !=
    null;

/// Seeds the flag (used by the test harness so other tests skip onboarding).
Future<void> seedOnboardingDone(AppDatabase db) => markOnboardingDone(db);

/// Installs from before onboarding existed (Sprints 1–5) already have data:
/// they are not on their first launch, so onboarding is marked done.
Future<void> skipOnboardingForExistingData(Repositories repos) async {
  if (await onboardingDone(repos.db)) return;
  final hasData =
      (await repos.tasks.getAll()).isNotEmpty ||
      (await repos.documents.getAll()).isNotEmpty ||
      (await repos.atcRules.getAll()).isNotEmpty;
  if (hasData) await markOnboardingDone(repos.db);
}
