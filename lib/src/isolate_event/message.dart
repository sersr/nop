import 'sender_platform/sender.dart';
export 'sender_platform/sender.dart';

typedef KeyControllerCallback = void Function(
    dynamic identityKey, KeyType keyType, String? isolateName);

enum KeyType { pause, resume, cancel, closeServer }

abstract class ServerName {
  String? get serverName;
}

class KeyController implements ServerName {
  KeyController(this.key, this.keyType, this.serverName);
  final dynamic key;
  final KeyType keyType;
  @override
  String? serverName;
  @override
  String toString() {
    return 'KeyController: key: $key, keyType: $keyType, isolateName: $serverName';
  }
}

enum StreamState {
  done,
  error,
}

class SendMessage implements ServerName {
  SendMessage(this.type, this.args, this.uniqueKey, this.serverName);
  final dynamic type;
  final dynamic args;
  @override
  final String serverName;

  SendHandle? _sendHandle;
  bool get dirty => _sendHandle == null;

  void reset(SendHandle sendHandle) {
    _sendHandle = sendHandle;
  }

  SendHandle get sendHandle => _sendHandle!;
  final Object uniqueKey;
  @override
  String toString() {
    return 'SendMessage: type: $type, args: $args,sendHandle: #${_sendHandle.hashCode}, ident: uniqueKey#${uniqueKey.hashCode}';
  }
}

enum Result {
  success,
  failed,
  error,
}

class ReceiveMessage {
  ReceiveMessage({
    required this.data,
    required this.uniqueKey,
    this.result = Result.success,
  });
  final dynamic uniqueKey;
  final dynamic data;
  final Result result;
  @override
  String toString() {
    return 'ReceiveMessage: ident: #${uniqueKey.hashCode}, data: $data, result: $result';
  }
}
