import '../../utils.dart';
import 'event.dart';
import 'message.dart';
import 'sender_private_handle.dart';

mixin SendEventPortMixin on SendEventFutureMixin, SendEventPortStreamMixin {}

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

  final _futureLists = <ListKey, SenderCompleterPrivateHandle>{};

  @override
  Future<T> sendMessage<T>(type, args, {required Type protocol}) {
    final key = ListKey([type, args, T, protocol]);

    if (_futureLists.containsKey(key)) {
      return _futureLists[key]!.future as Future<T>;
    }

    final sender = SenderCompleterPrivateHandle<T>(_sendEventRemove);
    sender.messageKey = key;
    _futureLists[key] = sender;

    final id = sender.identityKey;
    sender.protocol = protocol;
    sender.nullOnError = nullOnError;

    send(SendMessage(type, args, id, protocol));

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

  void _sendStreamEventRemove(Sender sender) {
    assert(sender is SenderStreamPrivateHandle);
    _streamLists.remove(sender.messageKey);
  }

  final _streamLists = <Object, SenderStreamPrivateHandle>{};

  @override
  Stream<T> sendMessageStream<T>(
    type,
    args, {
    bool unique = false,
    bool cached = false,
    required Type protocol,
  }) {
    Object key;
    if (unique) {
      key = Object();
    } else {
      key = ListKey([type, args, T, protocol]);
    }
    final shouldCached = cached && !unique;
    if (_streamLists.containsKey(key)) {
      return _streamLists[key]!.stream as Stream<T>;
    }

    final sender = SenderStreamPrivateHandle<T>(
      _sendStreamEventRemove,
      _sendKey,
      shouldCached,
    );
    sender.messageKey = key;
    _streamLists[key] = sender;

    final id = sender.identityKey;
    sender.protocol = protocol;
    sender.nullOnError = nullOnError;

    send(SendMessage(type, args, id, protocol));
    return sender.streamAsync;
  }

  void _sendKey(dynamic id, KeyType keyType, Type? protocol) {
    send(KeyController(id, keyType, protocol));
  }
}
