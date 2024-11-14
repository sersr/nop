import '../../../isolate_event.dart';

mixin Sender {
  void addData(data);
  void addError(Object error, StackTrace stackTrace);
  void cancel();
  late final Object identityKey = Object();
  Object? messageKey;
  String? serverName;

  bool nullOnError = false;
}

dynamic materialize(dynamic data) {
  return data;
}

typedef IsolateRemoteServer = LocalRemoteServer;