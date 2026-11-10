import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/region.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/premium/ui/premium_refresher.dart';
import 'features/capture/share_in_listener.dart';
import 'features/security/lock_gate.dart';
import 'features/settings/settings_providers.dart';
import 'features/widget/widget_click_listener.dart';

/// Marks every element for one rebuild (keeps all state).
void _redrawAll() {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

class LifeOsApp extends ConsumerWidget {
  const LifeOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    // Pure helpers (dates, labels) read the language from here.
    AppLocale.current = localeOf(settings);
    // …and the currency symbol, week and date order (PBI-035). Nothing
    // inherits the region the way it inherits the language, so on a change
    // every live screen is redrawn once — state (open tabs, a field being
    // typed in) is kept.
    final region = regionOf(settings);
    if (region != AppRegion.current) {
      AppRegion.current = region;
      WidgetsBinding.instance.addPostFrameCallback((_) => _redrawAll());
    }
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
          // arrive at any time (PBI-003), and so can a widget tap
          // (PBI-033) — the target shows after unlock.
          child: LockGate(
            child: PremiumRefresher(
              child: ShareInListener(
                child: WidgetClickListener(child: child!),
              ),
            ),
          ),
        );
      },
    );
  }
}
