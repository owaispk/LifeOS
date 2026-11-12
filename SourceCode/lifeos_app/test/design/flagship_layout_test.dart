// PBI-031 Flagship compact layout: density (AC1), alignment (AC2), tap
// targets (AC3), no overflow (AC4), one spacing source (AC5), Classic
// unchanged (AC6).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/theme/tokens.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../widget_test_utils.dart';
import 'density_test.dart' show phone, seed, visible;

const _screens = ['Home', 'Tasks', 'Vault', 'Money'];

Future<void> setLook(
  TestApp app,
  WidgetTester tester, {
  String? language,
  String? darkMode,
  String? template,
}) => app.write(tester, () async {
  final row = (await app.repos.userSettings.getAll()).first;
  await app.repos.userSettings.update(
    row.id,
    UserSettingsCompanion(
      language: language == null ? const Value.absent() : Value(language),
      darkMode: darkMode == null ? const Value.absent() : Value(darkMode),
      themeTemplate: template == null ? const Value.absent() : Value(template),
    ),
  );
});

Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'More');
  await tester.tap(find.byKey(const ValueKey('more-settings')));
  await tester.pumpAndSettle();
}

/// Section headers: the bold, letter-spaced caps used on every screen.
Iterable<Rect> sectionHeaders(WidgetTester tester) sync* {
  for (final e in find.byType(Text).evaluate()) {
    final t = e.widget as Text;
    final style = t.style;
    final data = t.data ?? '';
    if (style?.letterSpacing == 0.8 &&
        style?.fontWeight == FontWeight.w700 &&
        data.isNotEmpty &&
        data == data.toUpperCase()) {
      final box = e.renderObject;
      if (box is RenderBox && box.hasSize && box.attached) {
        yield box.localToGlobal(Offset.zero) & box.size;
      }
    }
  }
}

/// The start edge of every list row's leading content (icon/emoji column).
Iterable<double> leadingStarts(WidgetTester tester, {required bool rtl}) sync* {
  for (final e in find.byType(ListTile).evaluate()) {
    final tile = e.widget as ListTile;
    if (tile.leading == null) continue;
    // Rows inside a card align with the card, which sits on the gutter.
    if (e.findAncestorWidgetOfExactType<Card>() != null) continue;
    final leading = find.descendant(
      of: find.byWidget(tile),
      matching: find.byWidget(tile.leading!),
    );
    if (leading.evaluate().isEmpty) continue;
    final box = leading.evaluate().first.renderObject;
    if (box is! RenderBox || !box.attached) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    // Task rows: the visual circle sits 8 dp inside the leading button.
    final inset = tile.leading is IconButton ? 8.0 : 0.0;
    yield rtl ? 412 - r.right + inset : r.left + inset;
  }
}

void main() {
  appTest('AC1: at least 30% more on one screen than before', (
    tester,
    app,
  ) async {
    await phone(tester);
    await seed(app, tester);
    // Baseline (before PBI-031): Home 3 sections / 4 tasks, Tasks 11,
    // Vault all 8 folders, Money 4.
    expect(
      visible(
        tester,
        'home-',
        where: (k) => const {
          'home-score',
          'home-attention',
          'home-today',
          'home-money',
        }.contains(k),
      ),
      4,
      reason: 'score, attention, today and the money strip',
    );
    expect(
      visible(
        tester,
        'attention-',
        where: (k) =>
            !k.contains('swipe') &&
            !k.contains('see-all') &&
            !k.contains('empty'),
      ),
      3,
    );
    expect(visible(tester, 'task-'), greaterThanOrEqualTo(5));
    await openTab(tester, 'Tasks');
    expect(visible(tester, 'task-'), greaterThanOrEqualTo(15));
    await openTab(tester, 'Vault');
    expect(
      visible(tester, 'folder-', where: (k) => !k.startsWith('folder-count')),
      8,
    );
    await openTab(tester, 'Money');
    // Since PBI-038 F-02 (dense summary, owner decision 2026-11-11) the
    // first Money screen is the month at a glance — total, salary left,
    // three stats, categories and bills still to pay — and the expense
    // rows follow below it, instead of six expense rows.
    expect(
      visible(
        tester,
        'money-',
        where: (k) =>
            const {'money-hero', 'money-stats', 'money-coming-up'}.contains(k),
      ),
      3,
      reason: 'hero, stat tiles and coming up fit on one screen',
    );
  });

  for (final rtl in [false, true]) {
    appTest(
      'AC2: headers and row icons share the gutter (${rtl ? 'Urdu, RTL' : 'English'})',
      (tester, app) async {
        await phone(tester);
        await seed(app, tester);
        if (rtl) await setLook(app, tester, language: 'ur');
        final gutter = Tokens.gutter;
        Future<void> check(String screen) async {
          final headers = sectionHeaders(tester).toList();
          for (final h in headers) {
            final start = rtl ? 412 - h.right : h.left;
            expect(start, closeTo(gutter, 1), reason: '$screen header');
          }
          for (final s in leadingStarts(tester, rtl: rtl)) {
            expect(s, closeTo(gutter, 2.5), reason: '$screen row icon');
          }
        }

        await check('Home');
        for (final tab in ['Tasks', 'Vault', 'Money']) {
          await openTab(tester, rtl ? _urduTab(tab) : tab);
          await check(tab);
        }
      },
    );
  }

  appTest('AC3: every tappable control is at least 48 × 48 dp', (
    tester,
    app,
  ) async {
    await phone(tester);
    await seed(app, tester);
    final handle = tester.ensureSemantics();
    for (final tab in _screens) {
      await openTab(tester, tab);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
    await openSettings(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  for (final scale in [1.0, 1.3]) {
    for (final dark in [false, true]) {
      for (final ur in [false, true]) {
        appTest(
          'AC4: no overflow · text ×$scale · ${dark ? 'dark' : 'light'} · '
          '${ur ? 'Urdu' : 'English'}',
          (tester, app) async {
            await phone(tester);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await seed(app, tester);
            await setLook(
              app,
              tester,
              language: ur ? 'ur' : 'en',
              darkMode: dark ? 'dark' : 'light',
            );
            noOverflow(tester, 'Home');
            for (final tab in _screens.skip(1)) {
              await openTab(tester, ur ? _urduTab(tab) : tab);
              noOverflow(tester, tab);
            }
            await openTab(tester, ur ? _urduTab('More') : 'More');
            await tester.tap(find.byKey(const ValueKey('more-settings')));
            await tester.pumpAndSettle();
            noOverflow(tester, 'Settings');
          },
        );
      }
    }
  }

  test('AC5: no raw padding or gap numbers in lib/features', () {
    final raw = RegExp(
      r'(EdgeInsets(Directional)?\.[a-zA-Z]+\([^)]*:\s*[1-9]\d*(\.\d+)?\b'
      r'|EdgeInsets(Directional)?\.all\([1-9]'
      r'|SizedBox\((width|height):\s*[1-9]\d*(\.\d+)?\s*[,)]'
      r'|minTileHeight:\s*[1-9])',
    );
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (raw.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1} ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('AC6: Classic keeps the roomy spacing and text exactly', () {
    const r = AppSpacing.roomy;
    expect(
      [r.xs, r.s, r.m, r.l, r.xl, r.rowTwoLine, r.navBar, r.listEnd, r.body],
      [4, 8, 16, 24, 32, 64, 72, 120, 16],
    );
    const c = AppSpacing.compact;
    expect(
      [c.m, c.l, c.xl, c.rowOneLine, c.rowTwoLine, c.navBar, c.body],
      [12, 16, 24, 48, 56, 64, 15],
    );
    for (final v in [c.xs, c.s, c.m, c.l, c.xl, c.gutter, r.gutter]) {
      expect(v % 4, 0, reason: 'on the 4 dp grid');
    }
  });

  appTest('AC6: switching to Classic applies the roomy scale', (
    tester,
    app,
  ) async {
    await phone(tester);
    expect(AppSpacing.current.isCompact, isTrue);
    await setLook(app, tester, template: 'classic');
    expect(identical(AppSpacing.current, AppSpacing.roomy), isTrue);
    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      AppSpacing.roomy.navBar,
    );
    await setLook(app, tester, template: 'funky');
    expect(AppSpacing.current.isCompact, isTrue, reason: 'Funky is compact');
    await setLook(app, tester, template: 'flagship');
  });
}

/// Fails with the overflowing widget's ancestry, so a failure says where.
void noOverflow(WidgetTester tester, String screen) {
  final e = tester.takeException();
  if (e == null) return;
  final text = e is FlutterError
      ? e.diagnostics.map((d) => d.toStringDeep()).join('\n')
      : '$e';
  final at = text.indexOf('creator');
  fail(
    '$screen: ${text.split('\n').first}\n'
    '${at < 0 ? text : text.substring(at, (at + 1500).clamp(0, text.length))}',
  );
}

String _urduTab(String tab) => switch (tab) {
  'Home' => 'ہوم',
  'Tasks' => 'کام',
  'Vault' => 'والٹ',
  'Money' => 'پیسے',
  _ => 'مزید',
};
