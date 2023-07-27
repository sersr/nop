mixin Sender {
  void addData(data);
  void addError(Object error, StackTrace stackTrace);
  void cancel();
  late final Object identityKey = Object();
  Object? messageKey;
  String? serverName;

  bool nullOnError = false;
}
