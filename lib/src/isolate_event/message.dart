import 'sender_platform/sender.dart';
export 'sender_platform/sender.dart';

typedef KeyControllerCallback =
    void Function(dynamic identityKey, KeyType keyType, Type? protocol);

enum KeyType { pause, resume, cancel, closeServer, connectToProtocol }

abstract class ServerName {
  Type? get protocol;
}

class KeyController implements ServerName {
  KeyController(this.key, this.keyType, this.protocol);
  final dynamic key;
  final KeyType keyType;
  @override
  Type? protocol;
  @override
  String toString() {
    return 'KeyController: key: $key, keyType: $keyType, isolateName: $protocol';
  }
}

enum StreamState { done }

class SendMessage implements ServerName {
  SendMessage(this.type, this.args, this.uniqueKey, this.protocol);
  final Enum type;
  final dynamic args;
  @override
  final Type protocol;

  SendHandle? _sendHandle;
  bool get dirty => _sendHandle == null;

  void reset(SendHandle sendHandle) {
    _sendHandle = sendHandle;
  }

  void receipt(dynamic data, {Result result = .success}) {
    var sendHandle = this.sendHandle;
    if (uniqueKey case SendHandle sendHandle) {
      sendHandle.send(data);
      return;
    }

    sendHandle.send(
      ReceiveMessage(data: data, uniqueKey: uniqueKey, result: result),
    );
  }

  SendHandle get sendHandle => _sendHandle!;
  final Object uniqueKey;
  @override
  String toString() {
    return 'SendMessage: type: $type, args: $args,sendHandle: #${_sendHandle.hashCode}, ident: uniqueKey#${uniqueKey.hashCode}';
  }
}

enum Result { success, failed, error }

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
