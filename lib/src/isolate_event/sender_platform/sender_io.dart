import 'dart:isolate';

mixin Sender {
  void addData(data);
  void addError(Object error, StackTrace stackTrace);
  void cancel();
  late final Object identityKey = Capability();
  Object? messageKey;
  String? serverName;
}
