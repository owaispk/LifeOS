// PBI-033 AC4: the lifeos:// table maps widget taps to router locations.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/router/deep_links.dart';

void main() {
  test('known targets', () {
    expect(deepLinkLocation(Uri.parse('lifeos://home')), '/home');
    expect(deepLinkLocation(Uri.parse('lifeos://score')), '/home/score');
    expect(deepLinkLocation(Uri.parse('lifeos://task/t42')), '/tasks/task/t42');
  });

  test('anything else under the scheme lands on Home', () {
    expect(deepLinkLocation(Uri.parse('lifeos://unknown')), '/home');
    expect(deepLinkLocation(Uri.parse('lifeos://task')), '/home');
    expect(deepLinkLocation(Uri.parse('lifeos://')), '/home');
  });

  test('not ours → null', () {
    expect(deepLinkLocation(null), null);
    expect(deepLinkLocation(Uri.parse('https://example.com')), null);
  });
}
