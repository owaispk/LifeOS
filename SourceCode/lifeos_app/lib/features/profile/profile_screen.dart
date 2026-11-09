import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart' show personsProvider;
import '../../data/db/app_database.dart';
import '../../shared/widgets/section_header.dart';
import '../home/domain/attention.dart';
import '../settings/settings_providers.dart';
import '../vault/ui/vault_sheets.dart' show EmojiPicker, personEmojis;
import '../vault/vault_providers.dart' show vaultServiceProvider;

/// The Me-person (seeded, never deletable), live.
final selfPersonProvider = Provider<Person?>(
  (ref) => (ref.watch(personsProvider).value ?? const <Person>[])
      .where((p) => p.relation == 'self')
      .firstOrNull,
);

/// More → My Profile (PBI-035): who you are and how LifeOS talks to you.
/// Name and avatar live on the Me-person shared with Vault and Tasks; the
/// rest are settings. Nothing here assumes a region or religion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider).value;
    final self = ref.watch(selfPersonProvider);
    final now = ref.watch(nowProvider)();
    final settings = ref.read(settingsServiceProvider);
    final style = greetStyleOf(s);

    Future<void> saveSelf({String? name, String? avatar}) async {
      if (self == null) return;
      final n = (name ?? self.name).trim();
      if (n.isEmpty) return; // a name is required; keep the last good one
      await ref
          .read(vaultServiceProvider)
          .updatePerson(
            self.id,
            name: n,
            relation: 'self',
            avatar: avatar ?? self.avatar,
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.mrProfile)),
      body: ListView(
        key: const ValueKey('profile-list'),
        padding: EdgeInsets.only(bottom: Tokens.listEnd),
        children: [
          // Live preview: exactly what Home will say.
          Padding(
            padding: EdgeInsets.all(Tokens.gutter),
            child: Row(
              children: [
                Text(
                  self?.avatar ?? '👤',
                  key: const ValueKey('profile-avatar'),
                  style: const TextStyle(fontSize: 40),
                ),
                SizedBox(width: Tokens.spaceM),
                Expanded(
                  child: Text(
                    greeting(self, now, style: style, custom: s?.greetCustom ?? ''),
                    key: const ValueKey('profile-preview'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l.profileAboutYou),
          if (self != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: TextFormField(
                key: const ValueKey('profile-name'),
                // The seeded placeholder "Me" shows as empty with a prompt.
                initialValue: self.name == 'Me' ? '' : self.name,
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l.profileNameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => saveSelf(name: v),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: EmojiPicker(
              options: personEmojis,
              selected: self?.avatar ?? '',
              onSelected: (e) => saveSelf(avatar: e),
            ),
          ),
          SectionHeader(l.settingsLanguage),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            child: SegmentedButton<String>(
              key: const ValueKey('profile-language'),
              segments: [
                ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                ButtonSegment(value: 'ur', label: Text(l.languageUrdu)),
              ],
              selected: {s?.language ?? 'en'},
              onSelectionChanged: (v) => settings.setLanguage(v.first),
            ),
          ),
          SectionHeader(l.setGreeting),
          RadioGroup<String>(
            groupValue: style.name,
            onChanged: (v) => settings.setGreeting(
              GreetStyle.values.asNameMap()[v] ?? GreetStyle.auto,
            ),
            child: Column(
              children: [
                for (final (key, label) in [
                  ('auto', l.setGreetingAuto),
                  ('salam', l.setGreetingSalam),
                  ('namaste', l.setGreetingNamaste),
                  ('hello', l.setGreetingHello),
                  ('custom', l.setGreetingCustom),
                ])
                  RadioListTile<String>(
                    key: ValueKey('set-greet-$key'),
                    value: key,
                    title: Text(label),
                    dense: true,
                  ),
              ],
            ),
          ),
          if (style == GreetStyle.custom)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
              child: TextFormField(
                key: const ValueKey('set-greet-custom-text'),
                initialValue: s?.greetCustom ?? '',
                maxLength: 24,
                decoration: InputDecoration(hintText: l.setGreetingCustomHint),
                onChanged: (v) =>
                    settings.setGreeting(GreetStyle.custom, custom: v),
              ),
            ),
        ],
      ),
    );
  }
}
