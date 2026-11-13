import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_settings/app_settings.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../account/account_providers.dart';
import '../ai/ai_providers.dart';
import '../ai/ui/ai_settings_screen.dart' show aiSettingsRoute;
import '../calendar/calendar_providers.dart';
import '../premium/premium_providers.dart';
import '../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../../shared/format.dart';
import '../../shared/widgets/section_header.dart';
import '../capture/capture_providers.dart' show vaultRootProvider;
import '../security/lock_gate.dart';
import '../security/security_providers.dart';
import 'data/data_service.dart';
import 'settings_providers.dart';

final dataServiceProvider = Provider<DataService>((ref) {
  Directory? root;
  try {
    root = ref.watch(vaultRootProvider);
  } on Object {
    root = null; // web preview: no Vault folder
  }
  return DataService(
    ref.watch(repositoriesProvider),
    ref.watch(vaultFilesProvider),
    ref.watch(keyStoreProvider),
    root,
  );
});

/// Shares a finished export ZIP; the temporary file is deleted afterwards.
final shareExportProvider = Provider<Future<void> Function(List<int> zip)>(
  (ref) => (zip) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}LifeOS-export.zip');
    await f.writeAsBytes(zip, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path, mimeType: 'application/zip')]),
      );
    } finally {
      if (await f.exists()) await f.delete();
    }
  },
);

/// Notification domains with a toggle (PBI-023).
const notifyDomains = ['money', 'mind', 'vault', 'health', 'people'];

Map<String, bool> domainsOf(UserSettingsRow? s) {
  try {
    return (jsonDecode(s?.notifDomains ?? '{}') as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v == true),
    );
  } on Object {
    return const {};
  }
}

/// 5.6 Settings (PBI-025).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider).value;
    final canAuth = ref.watch(canAuthenticateProvider).value ?? false;
    final service = ref.read(settingsServiceProvider);
    Future<void> set(UserSettingsCompanion c) => service.update(c);
    final domains = domainsOf(s);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        key: const ValueKey('settings-list'),
        padding: EdgeInsets.only(bottom: Tokens.listEnd),
        children: [
          SectionHeader(l.settingsSecurity),
          SwitchListTile(
            key: const ValueKey('set-app-lock'),
            title: Text(l.appLock),
            subtitle: Text(canAuth ? l.appLockSub : l.lockUnavailable),
            value: (s?.appLock ?? false) && canAuth,
            onChanged: canAuth
                ? (v) async {
                    await set(UserSettingsCompanion(appLock: Value(v)));
                    // The widget privacy choice, once (PBI-033 AC5).
                    if (v && context.mounted) {
                      await _maybePromptWidgetDetails(context, service, s);
                    }
                  }
                : null,
          ),
          SwitchListTile(
            key: const ValueKey('set-widget-details'),
            title: Text(l.setWidgetDetails),
            subtitle: Text(l.setWidgetDetailsSub),
            value: s?.widgetDetails ?? true,
            onChanged: (v) => service.setWidgetDetails(v),
          ),
          SwitchListTile(
            key: const ValueKey('set-vault-lock'),
            title: Text(l.vaultLock),
            subtitle: Text(canAuth ? l.vaultLockSub : l.lockUnavailable),
            value: (s?.vaultLock ?? false) && canAuth,
            onChanged: canAuth
                ? (v) => set(UserSettingsCompanion(vaultLock: Value(v)))
                : null,
          ),
          ListTile(
            key: const ValueKey('set-auto-lock'),
            title: Text(l.autoLock),
            trailing: DropdownButton<int>(
              value: s?.autoLockMin ?? 5,
              onChanged: (v) =>
                  set(UserSettingsCompanion(autoLockMin: Value(v ?? 5))),
              items: [
                for (final m in const [1, 5, 15, 30])
                  DropdownMenuItem(
                    value: m,
                    child: Text(l.autoLockMinutes('$m')),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            key: const ValueKey('set-screenshot'),
            title: Text(l.screenshotBlock),
            value: s?.screenshotBlock ?? false,
            onChanged: (v) =>
                set(UserSettingsCompanion(screenshotBlock: Value(v))),
          ),
          ListTile(
            key: const ValueKey('set-share-history'),
            leading: const Icon(Icons.history),
            title: Text(l.shHistory),
            subtitle: Text(l.shHistorySub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/settings/shares'),
          ),
          SectionHeader(l.calSection),
          const _CalendarSettings(),
          SectionHeader(l.settingsNotifications),
          ListTile(
            key: const ValueKey('set-digest'),
            title: Text(l.digestTime),
            trailing: Text(_hm(s?.digestTime ?? '07:30')),
            onTap: () async {
              final t = await _pickTime(context, s?.digestTime ?? '07:30');
              if (t != null) {
                await set(UserSettingsCompanion(digestTime: Value(t)));
              }
            },
          ),
          ListTile(
            key: const ValueKey('set-quiet'),
            title: Text(l.quietHours),
            trailing: Text(
              l.quietHoursValue(
                _hm(s?.quietStart ?? '22:00'),
                _hm(s?.quietEnd ?? '07:00'),
              ),
            ),
            onTap: () async {
              final from = await _pickTime(context, s?.quietStart ?? '22:00');
              if (from == null || !context.mounted) return;
              final to = await _pickTime(context, s?.quietEnd ?? '07:00');
              if (to == null) return;
              await set(
                UserSettingsCompanion(
                  quietStart: Value(from),
                  quietEnd: Value(to),
                ),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.gutter,
              Tokens.spaceS,
              Tokens.gutter,
              0,
            ),
            child: Text(l.notifyAbout),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: Wrap(
              spacing: Tokens.spaceS,
              children: [
                for (final d in notifyDomains)
                  FilterChip(
                    key: ValueKey('set-domain-$d'),
                    label: Text(_domainLabel(l, d)),
                    selected: domains[d] ?? true,
                    onSelected: (on) => set(
                      UserSettingsCompanion(
                        notifDomains: Value(jsonEncode({...domains, d: on})),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(l.settingsLanguage),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: SegmentedButton<String>(
              key: const ValueKey('set-language'),
              segments: [
                ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                ButtonSegment(value: 'ur', label: Text(l.languageUrdu)),
              ],
              selected: {s?.language ?? 'en'},
              onSelectionChanged: (v) => service.setLanguage(v.first),
            ),
          ),
          SectionHeader(l.settingsAppearance),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: SegmentedButton<String>(
              key: const ValueKey('set-theme'),
              segments: [
                ButtonSegment(value: 'system', label: Text(l.themeSystem)),
                ButtonSegment(value: 'light', label: Text(l.themeLight)),
                ButtonSegment(value: 'dark', label: Text(l.themeDark)),
              ],
              selected: {s?.darkMode ?? 'system'},
              onSelectionChanged: (v) =>
                  set(UserSettingsCompanion(darkMode: Value(v.first))),
            ),
          ),
          RadioGroup<String>(
            groupValue: s?.themeTemplate ?? 'flagship',
            onChanged: (v) =>
                set(UserSettingsCompanion(themeTemplate: Value(v!))),
            child: Column(
              children: [
                for (final (key, label) in [
                  ('flagship', l.templateFlagship),
                  ('funky', l.templateFunky),
                  ('classic', l.templateClassic),
                ])
                  RadioListTile<String>(
                    key: ValueKey('set-template-$key'),
                    value: key,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          SectionHeader(l.settingsData),
          ListTile(
            key: const ValueKey('set-export'),
            leading: const Icon(Icons.ios_share),
            title: Text(l.exportData),
            subtitle: Text(l.exportDataSub),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            key: const ValueKey('set-trash'),
            leading: const Icon(Icons.delete_outline),
            title: Text(l.trash),
            onTap: () => context.go('/vault/trash'),
          ),
          ListTile(
            key: const ValueKey('set-diagnostics'),
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l.dgEntry),
            subtitle: Text(l.dgEntrySub),
            onTap: () => context.go('/more/settings/diagnostics'),
          ),
          ListTile(
            key: const ValueKey('set-delete-all'),
            leading: Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l.deleteAll),
            subtitle: Text(l.deleteAllSub),
            onTap: () => _deleteAll(context, ref),
          ),
          SectionHeader(l.aiSection),
          ListTile(
            key: const ValueKey('set-ai'),
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l.aiTitle),
            subtitle: Text(
              ref.watch(aiSettingsProvider).value?.isConfigured ?? false
                  ? l.aiApiKeyStored
                  : l.aiNotConfigured,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              // Re-auth before the provider settings can even be seen:
              // pointing the app at a hostile endpoint is an
              // exfiltration path (PBI-027a AC6).
              if (s?.appLock ?? false) {
                final ok = await ref
                    .read(authenticatorProvider)
                    .authenticate(l.aiReauth);
                if (!ok) return;
              }
              if (context.mounted) context.go(aiSettingsRoute);
            },
          ),
          SectionHeader(l.settingsPremium),
          ListTile(
            key: const ValueKey('set-premium'),
            leading: const Text('⭐', style: TextStyle(fontSize: 22)),
            title: Text(l.settingsPremium),
            subtitle: Text(
              ref.watch(premiumProvider) ? l.pmYourePremium : l.pmHeadline,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(premiumRoute),
          ),
          SectionHeader(l.acctSettingsTitle),
          const _AccountSettings(),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l.exporting)));
    final result = await ref.read(dataServiceProvider).export();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l.exportDone('${result.documentCount}'))),
      );
    await ref.read(shareExportProvider)(result.zip);
  }

  /// Enabling App Lock offers — once — to hide task titles and amounts on
  /// the home-screen widget (PBI-033 AC5).
  Future<void> _maybePromptWidgetDetails(
    BuildContext context,
    SettingsService service,
    UserSettingsRow? s,
  ) async {
    if (!(s?.widgetDetails ?? true)) return; // already hidden
    if (!await service.shouldPromptWidgetDetails()) return;
    if (!context.mounted) return;
    final l = context.l10n;
    final hide = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        key: const ValueKey('widget-details-prompt'),
        title: Text(l.wgLockPromptTitle),
        content: Text(l.wgLockPromptBody),
        actions: [
          TextButton(
            key: const ValueKey('widget-details-keep'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.wgLockPromptKeep),
          ),
          FilledButton(
            key: const ValueKey('widget-details-hide'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.wgLockPromptHide),
          ),
        ],
      ),
    );
    if (hide == true) await service.setWidgetDetails(false);
  }

  /// Double confirmation (AC5): a dialog, then typing DELETE.
  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final first = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        key: const ValueKey('delete-all-1'),
        title: Text(l.deleteAllTitle),
        content: Text(l.deleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('delete-all-continue'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.continueLabel),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final typed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const _TypeDeleteDialog(),
    );
    if (typed != true) return;
    await ref
        .read(dataServiceProvider)
        .deleteAll(ref.read(vaultCryptoProvider));
    if (context.mounted) context.go('/onboarding');
  }
}

class _TypeDeleteDialog extends StatefulWidget {
  const _TypeDeleteDialog();

  @override
  State<_TypeDeleteDialog> createState() => _TypeDeleteDialogState();
}

class _TypeDeleteDialogState extends State<_TypeDeleteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const ValueKey('delete-all-2'),
      title: Text(l.deleteAllConfirmTitle),
      content: TextField(
        key: const ValueKey('delete-all-field'),
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: l.deleteAllConfirmHint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('delete-all-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _ctrl.text.trim() == 'DELETE'
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(l.deleteForever),
        ),
      ],
    );
  }
}



String _domainLabel(AppLocalizations l, String d) => switch (d) {
  'money' => l.domainMoney,
  'mind' => l.domainMind,
  'vault' => l.domainVault,
  'health' => l.domainHealth,
  'people' => l.domainPeople,
  'work' => l.domainWork,
  _ => l.domainSoul,
};

/// "07:30" → "7:30 AM".
String _hm(String hhmm) {
  final parts = hhmm.split(':');
  return formatTime(
    DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1])),
  );
}

Future<String?> _pickTime(BuildContext context, String current) async {
  final parts = current.split(':');
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    ),
  );
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Device calendar (PBI-032): the master toggle, then which calendars to
/// show. Nothing calendar-related runs until the toggle goes on, and the
/// permission is asked for there and nowhere else (AC3, AC5).
class _CalendarSettings extends ConsumerWidget {
  const _CalendarSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(calendarOnProvider);
    final off = ref.watch(calendarsOffProvider);
    final settings = ref.read(calendarSettingsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: const ValueKey('set-calendar'),
          title: Text(l.calShowEvents),
          subtitle: Text(l.calShowEventsHint),
          value: on,
          onChanged: (want) async {
            if (!want) return settings.disable();
            // The switch only moves if the user allows it (AC3).
            if (await settings.enable()) return;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                key: const ValueKey('calendar-denied'),
                content: Text(l.calDenied),
                action: SnackBarAction(
                  label: l.calOpenSettings,
                  onPressed: AppSettings.openAppSettings,
                ),
              ),
            );
          },
        ),
        if (on)
          ref
              .watch(deviceCalendarsProvider)
              .when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (cals) => cals.isEmpty
                    ? ListTile(
                        key: const ValueKey('calendar-none'),
                        subtitle: Text(l.calNoCalendars),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            key: const ValueKey('calendar-which'),
                            title: Text(l.calWhichCalendars),
                          ),
                          for (final c in cals)
                            CheckboxListTile(
                              key: ValueKey('calendar-${c.id}'),
                              title: Text(c.name),
                              subtitle: c.account.isEmpty
                                  ? null
                                  : Text(c.account),
                              secondary: c.colorValue == null
                                  ? null
                                  : CircleAvatar(
                                      radius: Tokens.spaceS,
                                      backgroundColor: Color(c.colorValue!),
                                    ),
                              value: !off.contains(c.id),
                              onChanged: (v) =>
                                  settings.setCalendar(c.id, on: v ?? false),
                            ),
                        ],
                      ),
              ),
      ],
    );
  }
}

/// Account settings section (PBI-026a).
class _AccountSettings extends ConsumerWidget {
  const _AccountSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasAccount = ref.watch(hasAccountProvider);

    return hasAccount.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (hasAccount) => hasAccount
          ? ListTile(
              key: const ValueKey('set-account-active'),
              leading: const Icon(Icons.key_rounded),
              title: Text(l.acctSettingsHasAccount),
              subtitle: Text(l.acctSettingsHasAccountSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(viewPhraseRoute),
            )
          : ListTile(
              key: const ValueKey('set-account-create'),
              leading: const Icon(Icons.key_off_outlined),
              title: Text(l.acctSettingsNoAccount),
              subtitle: Text(l.acctSettingsNoAccountSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(createAccountRoute),
            ),
    );
  }
}
