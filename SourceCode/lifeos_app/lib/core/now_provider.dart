import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" as a local DateTime. Overridden in tests for a fixed clock.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);
