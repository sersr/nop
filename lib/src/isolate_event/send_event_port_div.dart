import '../../utils.dart';
import 'event.dart';
import 'message.dart';
import 'sender_private_handle.dart';

/// 每个任务都有一个独立的端口
mixin SendEventFutureMixin on SendEvent implements Messager {
  @override
  void dispose() {
    final futureSenders = List.of(_futureLists.values, growable: false);
    for (var e in futureSenders) {
      e.cancel();
    }

    _futureLists.clear();
    super.dispose();
  }

  void _sendEventRemove(Sender sender) {
    assert(sender is SenderPrivateHandle);
    _futureLists.remove(sender.messageKey);
  }

  dynamic _sendEventResolve(dynamic data) {
    if (data is ReceiveMessage) {
      if (data.result == Result.failed) assert(Log.w('failed'));
      return data.data;
    }
    return data;
  }

  final _futureLists = <ListKey, SenderCompleterPrivateHandle>{};

  @override
  Future<T?> sendMessage<T>(type, args, {String serverName = 'default'}) {
    final _key = ListKey([type, args, T, serverName]);

    if (_futureLists.containsKey(_key)) {
      return _futureLists[_key]!.future as Future<T?>;
    }

    final sender =
        SenderCompleterPrivateHandle<T?>(_sendEventRemove, _sendEventResolve);
    sender.messageKey = _key;
    _futureLists[_key] = sender;

    final id = sender.identityKey;
    sender.serverName = serverName;

    send(SendMessage(type, args, id, serverName));

    return sender.future;
  }
}

/// 每个任务都有一个独立的端口
mixin SendEventPortStreamMixin on SendEvent implements Messager {
  @override
  void dispose() {
    final streamSenders = List.of(_streamLists.values, growable: false);
    for (var s in streamSenders) {
      s.cancel();
    }
    _streamLists.clear();
    super.dispose();
  }

  void _sendEventRemove(Sender sender) {
    assert(sender is SenderStreamPrivateHandle);
    _streamLists.remove(sender.messageKey);
  }

  dynamic _sendEventResolve(dynamic data) {
    if (data is ReceiveMessage) {
      if (data.result == Result.failed) assert(Log.w('failed'));
      return data.data;
    }
    return data;
  }

  final _streamLists = <Object, SenderStreamPrivateHandle>{};

  @override
  Stream<T> sendMessageStream<T>(type, args,
      {bool unique = false,
      bool cached = false,
      String serverName = 'default'}) {
    Object key;
    if (unique) {
      key = Object();
    } else {
      key = ListKey([type, args, T, serverName]);
    }
    final shouldCached = cached && !unique;
    if (_streamLists.containsKey(key)) {
      return _streamLists[key]!.stream as Stream<T>;
    }

    final sender = SenderStreamPrivateHandle<T>(
        _sendEventRemove, _sendKey, _sendEventResolve, shouldCached);
    sender.messageKey = key;
    _streamLists[key] = sender;

    final id = sender.identityKey;
    sender.serverName = serverName;

    send(SendMessage(type, args, id, serverName));
    return sender.streamAsync;
  }

  void _sendKey(dynamic id, KeyType keyType, String? serverName) {
    send(KeyController(id, keyType, serverName));
  }
}
