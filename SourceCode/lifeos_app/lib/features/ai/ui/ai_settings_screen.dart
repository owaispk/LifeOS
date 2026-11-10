import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../premium/premium_providers.dart';
import '../../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../ai_providers.dart';

/// Where the AI settings live.
const aiSettingsRoute = '/more/settings/ai';

/// Prefilled provider choices. All speak the OpenAI chat API, so one
/// client serves every one of them.
class AiPreset {
  const AiPreset(this.name, this.baseUrl, this.model);
  final String name;
  final String baseUrl;
  final String model;
}

const aiPresets = [
  AiPreset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  AiPreset('Groq', 'https://api.groq.com/openai/v1', 'llama-3.1-8b-instant'),
  AiPreset('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  AiPreset('OpenRouter', 'https://openrouter.ai/api/v1', 'openai/gpt-4o-mini'),
  AiPreset('Mistral', 'https://api.mistral.ai/v1', 'mistral-small-latest'),
  AiPreset(
    'Gemini (compatible)',
    'https://generativelanguage.googleapis.com/v1beta/openai',
    'gemini-2.0-flash',
  ),
  AiPreset('Ollama (local)', 'http://localhost:11434/v1', 'llama3.1'),
  AiPreset('LM Studio (local)', 'http://localhost:1234/v1', 'local-model'),
];

/// Settings → AI (PBI-027a). Free users see the pitch and a lock; the
/// form itself is premium-only, and reaching it needs re-auth when App
/// Lock is on — pointing the app at a hostile endpoint would be a way
/// to siphon document text out.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = true;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  void _fillOnce(AiSettings s) {
    if (_loaded) return;
    _loaded = true;
    _baseUrl.text = s.baseUrl ?? '';
    _model.text = s.model ?? '';
    // The stored key is never put back in the field: it is write-only
    // from here on, and "saved on this phone only" says it exists.
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref
        .read(aiSettingsServiceProvider)
        .setProvider(
          baseUrl: _baseUrl.text,
          model: _model.text,
          apiKey: _key.text.isEmpty ? null : _key.text,
        );
    _key.clear();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    await _save();
    final settings = await ref.read(aiSettingsProvider.future);
    final provider = ref.read(llmProviderFactoryProvider)(settings);
    String? error;
    if (provider == null) {
      error = l.aiNotConfigured;
    } else {
      try {
        await provider.testConnection();
      } on AiFailure catch (e) {
        // The provider's own words, not ours (AC5).
        error = e.message;
      } on Object {
        error = l.aiNotConfigured;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _messageIsError = error != null;
      _message = error ?? l.aiTestOk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final premium = ref.watch(premiumProvider);
    final settings = ref.watch(aiSettingsProvider).value;
    if (settings != null) _fillOnce(settings);

    return Scaffold(
      appBar: AppBar(title: Text(l.aiSection)),
      body: ListView(
        key: const ValueKey('ai-settings-list'),
        padding: EdgeInsets.all(Tokens.spaceL),
        children: [
          Text(l.aiTitle, style: theme.textTheme.titleLarge),
          SizedBox(height: Tokens.spaceM),
          Text(
            settings?.mode == AiMode.managed
                ? l.aiPrivacyNoteManaged
                : l.aiPrivacyNote,
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: Tokens.spaceL),
          if (!premium) ...[
            // Visible but locked: the pitch is deliberate (AC4).
            Row(
              key: const ValueKey('ai-locked'),
              children: [
                const Icon(Icons.lock_outline),
                SizedBox(width: Tokens.spaceS),
                Expanded(child: Text(l.aiLockedPitch)),
              ],
            ),
            SizedBox(height: Tokens.spaceM),
            FilledButton(
              key: const ValueKey('ai-upgrade'),
              onPressed: () => context.go(premiumRoute),
              child: Text(l.aiUpgrade),
            ),
          ] else ...[
            // Managed is the default and needs nothing; the own-provider
            // form below is the advanced override (PBI-027b).
            ListTile(
              key: const ValueKey('ai-mode'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                settings?.mode == AiMode.managed
                    ? Icons.check_circle
                    : Icons.cloud_outlined,
              ),
              title: Text(
                settings?.mode == AiMode.managed
                    ? l.aiModeManaged
                    : l.aiModeOwn,
              ),
              subtitle: settings?.mode == AiMode.managed
                  ? Text(l.aiModeManagedSub)
                  : null,
              trailing: settings?.mode == AiMode.byok
                  ? TextButton(
                      key: const ValueKey('ai-use-managed'),
                      // Explicit, and the only way back: nothing ever
                      // reroutes text between modes on its own (AC4).
                      onPressed: () async {
                        await ref
                            .read(aiSettingsServiceProvider)
                            .setProvider(
                              baseUrl: null,
                              model: null,
                              apiKey: '',
                            );
                        _baseUrl.clear();
                        _model.clear();
                      },
                      child: Text(l.aiUseManaged),
                    )
                  : null,
            ),
            SizedBox(height: Tokens.spaceM),
            Text(l.aiAdvanced, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            Text(l.aiPreset, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            Wrap(
              spacing: Tokens.spaceS,
              runSpacing: Tokens.spaceS,
              children: [
                for (final p in aiPresets)
                  ActionChip(
                    key: ValueKey('ai-preset-${p.name}'),
                    label: Text(p.name),
                    onPressed: () => setState(() {
                      _baseUrl.text = p.baseUrl;
                      _model.text = p.model;
                    }),
                  ),
              ],
            ),
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('ai-base-url'),
              controller: _baseUrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.aiBaseUrl,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('ai-model'),
              controller: _model,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.aiModel,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            TextField(
              key: const ValueKey('ai-key'),
              controller: _key,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.aiApiKey,
                helperText: settings?.hasKey ?? false
                    ? l.aiApiKeyStored
                    : l.aiKeyHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('ai-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l.aiSave),
                  ),
                ),
                SizedBox(width: Tokens.spaceS),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('ai-test'),
                    onPressed: _busy ? null : _test,
                    child: Text(l.aiTest),
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              SizedBox(height: Tokens.spaceM),
              Text(
                _message!,
                key: const ValueKey('ai-message'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _messageIsError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
            SizedBox(height: Tokens.spaceL),
            Text(l.aiConsentSetting, style: theme.textTheme.labelLarge),
            SizedBox(height: Tokens.spaceS),
            SegmentedButton<AiConsent>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: AiConsent.ask, label: Text(l.aiConsentAsk)),
                ButtonSegment(value: AiConsent.always, label: Text(l.aiAlways)),
                ButtonSegment(value: AiConsent.never, label: Text(l.aiNever)),
              ],
              selected: {settings?.consent ?? AiConsent.ask},
              onSelectionChanged: (s) =>
                  ref.read(aiSettingsServiceProvider).setConsent(s.first),
            ),
          ],
        ],
      ),
    );
  }
}
