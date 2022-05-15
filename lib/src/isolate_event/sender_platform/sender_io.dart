import 'dart:isolate';

mixin Sender {
  void addData(data);
  void cancel();
  late final Object identityKey = Capability();
  Object? messageKey;
  String? serverName;
}
