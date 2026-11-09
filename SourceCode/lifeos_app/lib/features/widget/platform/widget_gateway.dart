// The phone's home-screen widget host (PBI-033). The real gateway talks
// to the `home_widget` plugin; tests and the web preview use fakes/no-ops.
import 'package:home_widget/home_widget.dart';

/// Pushes pre-rendered widget data to the launcher and surfaces widget
/// taps as `lifeos://` URIs.
abstract class WidgetGateway {
  /// Saves the snapshot JSON and asks the launcher to re-render. Also arms
  /// the plugin's scheduled update for just after midnight, so the widget
  /// swaps to the precomputed "tomorrow" data without the app (AC3).
  Future<void> push(String snapshotJson, {required DateTime nextMidnight});

  /// Widget taps while the app is alive.
  Stream<Uri?> get clicks;

  /// The URI the app was cold-started with, or null.
  Future<Uri?> initialUri();
}

/// Android implementation over the `home_widget` plugin.
class HomeWidgetGateway implements WidgetGateway {
  const HomeWidgetGateway();

  /// Key in the plugin's shared storage; the provider reads the same key.
  static const snapshotKey = 'snapshot';

  /// Must match the Kotlin class next to MainActivity.
  static const androidProvider = 'LifeOsWidgetProvider';

  @override
  Future<void> push(String snapshotJson, {required DateTime nextMidnight}) async {
    await HomeWidget.saveWidgetData<String>(snapshotKey, snapshotJson);
    await HomeWidget.updateWidget(androidName: androidProvider);
    await HomeWidget.cancelScheduledWidgetUpdates(
      androidName: androidProvider,
    );
    await HomeWidget.scheduleWidgetUpdates(
      [nextMidnight],
      androidName: androidProvider,
    );
  }

  @override
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;

  @override
  Future<Uri?> initialUri() => HomeWidget.initiallyLaunchedFromHomeWidget();
}

/// Web preview / tests default: does nothing.
class NoopWidgetGateway implements WidgetGateway {
  const NoopWidgetGateway();

  @override
  Future<void> push(String snapshotJson, {required DateTime nextMidnight}) async {}

  @override
  Stream<Uri?> get clicks => const Stream.empty();

  @override
  Future<Uri?> initialUri() async => null;
}
