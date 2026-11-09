import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/capture/share_in_listener.dart';
import 'features/security/lock_gate.dart';
import 'features/settings/settings_providers.dart';

class LifeOsApp extends ConsumerWidget {
  const LifeOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    // Pure helpers (dates, labels) read the language from here.
    AppLocale.current = localeOf(settings);
    final look = templateOf(settings);
    // Spacing and density follow the look (PBI-031).
    AppSpacing.current = AppTheme.spacingFor(look);
    final scale = textScaleOf(settings);
    return MaterialApp.router(
      onGenerateTitle: (context) => 'LifeOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(look),
      darkTheme: AppTheme.dark(look),
      themeMode: themeModeOf(settings),
      // Language switches instantly; Urdu lays out right-to-left (PBI-025).
      locale: localeOf(settings),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1) < scale
                  ? scale
                  : media.textScaler.scale(1),
            ),
          ),
          // App lock (PBI-024) covers everything; "Share to LifeOS" can
          // arrive at any time (PBI-003).
          child: LockGate(child: ShareInListener(child: child!)),
        );
      },
    );
  }
}
