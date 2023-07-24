import '../../utils.dart';
import 'event.dart';
import 'message.dart';
import 'sender_private_handle.dart';

@Deprecated('use SendEventFutureMixin or SendEventPortStreamMixin.')

/// 每个任务都有一个独立的端口
mixin SendEventPortMixin on SendEvent implements Messager {
  @override
  bool add(message) => false;

  @override
  void dispose() {
    final futureSenders = List.of(_futureLists.values, growable: false);
    final streamSenders = List.of(_streamLists.values, growable: false);
    for (var e in futureSenders) {
      e.cancel();
    }
    for (var s in streamSenders) {
      s.cancel();
    }
    _futureLists.clear();
    _streamLists.clear();
    super.dispose();
  }

  void _sendEventRemove(Sender sender) {
    if (sender is SenderStreamPrivateHandle) {
      _streamLists.remove(sender.messageKey);
    } else if (sender is SenderCompleterPrivateHandle) {
      _futureLists.remove(sender.messageKey);
    }
  }

  // dynamic _sendEventResolve(dynamic data) {
  //   if (data is ReceiveMessage) {
  //     if (data.result == Result.failed) assert(Log.w('failed'));
  //     return data.data;
  //   }
  //   return data;
  // }

  final _futureLists = <ListKey, SenderCompleterPrivateHandle>{};
  final _streamLists = <Object, SenderStreamPrivateHandle>{};

  @override
  Future<T> sendMessage<T>(type, args, {String serverName = 'default'}) {
    final key = ListKey([type, args, T, serverName]);

    if (_futureLists.containsKey(key)) {
      return _futureLists[key]!.future as Future<T>;
    }

    final sender = SenderCompleterPrivateHandle<T>(_sendEventRemove);
    sender.messageKey = key;
    _futureLists[key] = sender;

    _send(type, args, sender, serverName);
    return sender.future;
  }

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

    final sender =
        SenderStreamPrivateHandle<T>(_sendEventRemove, _sendKey, shouldCached);
    sender.messageKey = key;
    _streamLists[key] = sender;

    _send(type, args, sender, serverName);
    return sender.streamAsync;
  }

  void _send(dynamic type, dynamic args, Sender sender, String serverName) {
    final id = sender.identityKey;
    sender.serverName = serverName;

    send(SendMessage(type, args, id, serverName));
  }

  void _sendKey(dynamic id, KeyType keyType, String? serverName) {
    send(KeyController(id, keyType, serverName));
  }
}
