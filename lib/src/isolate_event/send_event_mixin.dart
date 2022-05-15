import 'dart:async';

import '../../utils.dart';
import 'event.dart';
import 'message.dart';
import 'sender_single.dart';

/// 在主隔离的所有消息接受操作都由[add]处理
///
/// 共享一个端口
///
/// ```dart
///   final rcPort = ReceivePort();
///   rcPort.listen((message) {
///     if(add(message)) return;
///     //...
///   }
/// ```
mixin SendEventMixin implements SendEvent, Messager {
  @override
  SendHandleOwner? getSendHandleOwner(String? serverName) => null;

  @override
  Map<String, List<Type>> getProtocols() => {};

  @override
  void notifyState(bool open) {}

  @override
  void onResume() {}

  @override
  void dispose() {
    final m = List.of(_messageCaches.values, growable: false);
    for (var e in m) {
      e.cancel();
    }
    _messageCaches.clear();
    _futureLists.clear();
    _streamLists.clear();
  }

  final _messageCaches = <dynamic, Sender>{};

  @override
  bool add(message) {
    if (message is ReceiveMessage) {
      final messageId = message.uniqueKey;
      final data = message.data;
      final messager = _messageCaches[messageId];
      if (messager != null) {
        messager.addData(data);
        return true;
      }
    }
    return false;
  }

  void _remove(Sender sender) {
    assert(_messageCaches.containsKey(sender.identityKey));

    _messageCaches.remove(sender.identityKey);
    if (sender is SenderCompleter) {
      _futureLists.remove(sender.messageKey);
    } else if (sender is SenderStreamController) {
      _streamLists.remove(sender.messageKey);
    }
  }

  final _futureLists = <ListKey, SenderCompleter>{};

  @override
  Future<T?> sendMessage<T>(dynamic type, dynamic args,
      {String serverName = 'default'}) {
    final _key = ListKey([type, args, T, serverName]);

    if (_futureLists.containsKey(_key)) {
      return _futureLists[_key]!.future as Future<T?>;
    }

    final sender = SenderCompleter<T?>(_remove);
    _futureLists[_key] = sender;
    sender.messageKey = _key;
    _send(type, args, sender, serverName);

    return sender.future;
  }

  final _streamLists = <Object, SenderStreamController>{};

  @override
  Stream<T> sendMessageStream<T>(dynamic type, dynamic args,
      {bool unique = false,
      bool cached = false,
      String serverName = 'default'}) {
    Object _key;
    if (unique) {
      _key = Object();
    } else {
      _key = ListKey([type, args, T, serverName]);
    }
    bool shouldCache = cached && !unique;
    if (_streamLists.containsKey(_key)) {
      return _streamLists[_key]!.stream as Stream<T>;
    }

    final sender = SenderStreamController<T>(_remove, _sendKey, shouldCache);
    _streamLists[_key] = sender;
    sender.messageKey = _key;
    _send(type, args, sender, serverName);

    return sender.streamAsync;
  }

  void _send(dynamic type, dynamic args, Sender sender, String serverName) {
    final _id = sender.identityKey;
    assert(!_messageCaches.containsKey(_id));
    sender.serverName = serverName;
    _messageCaches[_id] = sender;

    send(SendMessage(type, args, _id, serverName));
  }

  void _sendKey(dynamic id, KeyType keyType, String? serverName) {
    send(KeyController(id, keyType, serverName));
  }
}
