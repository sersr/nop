import 'package:flutter_test/flutter_test.dart';
import 'package:nop/src/utils/pretty_ext.dart';

void main() {
  test('log pretty', () {
    final map = {
      'hhlo': 11,
      'sss': ['s.', 1, 23],
      'map': {'1': 'ddd'}
    };

    // ignore: avoid_print
    print(map.logPretty());
  });
}
