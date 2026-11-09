import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_log.dart';

/// App and device facts for the log and `device.txt` (PBI-030). Nothing
/// personal: versions and the phone model only.
Future<Map<String, String>> deviceFacts() async {
  final facts = <String, String>{};
  try {
    final p = await PackageInfo.fromPlatform();
    facts['app'] = '${p.appName} ${p.version}+${p.buildNumber}';
  } on Object {
    facts['app'] = 'LifeOS';
  }
  facts['os'] = kIsWeb
      ? 'web'
      : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  try {
    if (!kIsWeb && Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      facts['device'] = '${a.manufacturer} ${a.model}';
      facts['android'] = 'API ${a.version.sdkInt} (${a.version.release})';
    }
  } on Object {
    // Unknown device: leave it out.
  }
  facts['build'] = kReleaseMode ? 'release' : 'debug';
  return facts;
}

/// Sends every uncaught error to the log (AC1): Flutter framework errors,
/// uncaught async/platform errors and errors from other isolates. The
/// default behaviour (console output in debug) is kept.
void captureErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.e('flutter', details.exceptionAsString(), details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e('uncaught', error, stack);
    return true; // handled: logged, the app keeps running
  };
  if (!kIsWeb) {
    Isolate.current.addErrorListener(
      RawReceivePort((dynamic pair) {
        final list = pair as List<dynamic>;
        AppLog.e(
          'isolate',
          list.first ?? 'error',
          list.last == null ? null : StackTrace.fromString('${list.last}'),
        );
      }).sendPort,
    );
  }
}

/// Logs app pause/resume and flushes the log when the app goes away.
class LogLifecycle {
  LogLifecycle() {
    AppLifecycleListener(
      onResume: () => AppLog.i('app', 'resumed'),
      onPause: () {
        AppLog.i('app', 'paused');
        AppLog.instance.flush();
      },
    );
  }
}
