mixin Sender {
  void addData(data);
  void cancel();
  late final Object identityKey = Object();
  Object? messageKey;
  String? serverName;
}
