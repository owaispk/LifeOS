import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/widget_gateway.dart';

/// The launcher's widget host. Overridden in `main()` with the real
/// `home_widget` gateway on Android; a no-op on the web preview and in
/// tests.
final widgetGatewayProvider = Provider<WidgetGateway>(
  (ref) => const NoopWidgetGateway(),
);
