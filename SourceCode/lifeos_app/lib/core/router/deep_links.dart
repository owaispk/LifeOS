/// `lifeos://` deep links (PBI-033): one table from URI to router
/// location, shared by every entry point that carries a URI into the app.
///
///   lifeos://home       → Home tab
///   lifeos://score      → Score breakdown
///   lifeos://task/`id`  → that task's detail screen
///
/// Anything else under the scheme lands on Home (PBI-033: "anywhere else
/// → Home"); a non-`lifeos` URI is not ours and returns null.
String? deepLinkLocation(Uri? uri) {
  if (uri == null || uri.scheme != 'lifeos') return null;
  final parts = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((s) => s.isNotEmpty),
  ];
  return switch (parts) {
    ['score'] => '/home/score',
    ['task', final id] => '/tasks/task/$id',
    _ => '/home',
  };
}
