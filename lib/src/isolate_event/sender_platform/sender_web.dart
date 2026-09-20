import 'dart:async';
import 'dart:typed_data';

import '../../../isolate_event.dart';

Object createIdentityKey() => Object();

dynamic materialize(dynamic data) {
  return data;
}

typedef IsolateRemoteServer<T> = LocalRemoteServer<T>;

class Uint8ListType with TransferType<Uint8List?> {
  Uint8ListType(this.list);
  final Uint8List? list;
  @override
  FutureOr<Uint8List?> decode() {
    return list;
  }

  @override
  FutureOr<void> encode() {}
}
