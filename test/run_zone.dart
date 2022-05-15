// ignore_for_file: avoid_print

import 'dart:async';

Future<void> runZone(FutureOr<void> Function() callback) async {
  return runZoned(callback,
      zoneSpecification: ZoneSpecification(print: (zone, parent, self, line) {
    return Zone.root.print(line);
  }));
}
