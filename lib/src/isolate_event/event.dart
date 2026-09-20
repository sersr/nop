import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:nop/nop.dart';

abstract mixin class Messager {
  Future<T> sendMessage<T>(
    dynamic type,
    dynamic args, {
    required Type protocol,
  });
  Stream<T> sendMessageStream<T>(
    dynamic type,
    dynamic args, {
    bool unique = false,
    bool cached = false,
    required Type protocol,
  });
}

extension SendMessageOption on Messager {
  Future<Option<T>> sendOption<T>(
    dynamic type,
    dynamic args, {
    required Type protocol,
  }) {
    return sendMessage(type, args, protocol: protocol).then((value) {
      assert(value is Option<T> || value == null);
      if (value is Option<T>) {
        return value;
      } else {
        // dynmaic
        if (value != null) {
          return Some(value);
        } else {
          return const None();
        }
      }
    }, onError: (e) => None<T>());
  }
}

abstract mixin class SendEvent {
  @protected
  bool add(message) => false;

  @protected
  void send(message);

  bool get nullOnError => true;

  @mustCallSuper
  @protected
  SendHandle? getRemoteSender(Type? protocol) => null;
  SendHandle get localSendHandle;

  @protected
  void notifyState(bool open) {}

  @mustCallSuper
  @protected
  void onResume() {}
  @mustCallSuper
  void dispose() {}
}

class ServerConfigurations<T> {
  ServerConfigurations({required this.args, required this.sendHandle});
  final T args;
  final SendHandle sendHandle;
}

typedef TaskCallback = FutureOr<void> Function();

abstract mixin class ResolveEvent {
  FutureOr<void> onInit();
  FutureOr<void> onClose();

  void onResolvedFailed(dynamic message) {}
  void onError(SendMessage message, Object error, StackTrace stackTrace) {}
}

final class ResolveItem {
  ResolveItem({required this.protocol, required this.protocolFns});

  final Type protocol;
  final List<Function> protocolFns;
}

mixin Resolve {
  SendHandle get localSendHandle => _rcHandle.sendHandle;

  late final _rcHandle = ReceiveHandle()..listen(listen);

  List<ResolveItem> get resolveItems;
  List<ResolveEvent> get resolveEvents;

  late final List<Type> protocols = resolveItems
      .map((e) => e.protocol)
      .toList();

  late SendHandleName currentLocalSendHandle = SendHandleName(
    localSendHandle,
    protocols: protocols,
    isRequest: false,
  );

  void run() {
    runZonedGuarded(_initState, (error, stack) {
      Log.e('error: $error\n$stack');
    });
  }

  final queue = TaskQueue();

  var _inited = false;
  void _initState() {
    if (_inited) return;
    _inited = true;

    queue.run(
      () => resolveEvents.map((e) => e.onInit()).whereType<Future>().wait,
    );
  }

  bool listen(message) {
    if (remove(message)) return true;
    final success = resolve(message);
    if (!success) {
      onResolvedFailed(message);
    }
    return success;
  }

  Future<void> onClose() async {
    if (!_inited) return;
    _inited = false;

    return queue.run(
      () => resolveEvents.map((e) => e.onClose()).whereType<Future>().wait,
    );
  }

  @protected
  bool resolve(message) {
    if (message is SendMessage) {
      final type = message.type;
      for (var item in resolveItems) {
        if (identical(type.runtimeType, item.protocol)) {
          try {
            final result = item.protocolFns.elementAt(type.index)(message.args);
            receipt(result, message);
          } catch (e, stacktrace) {
            receipt(null, message, error: (e, stacktrace));
          }
          return true;
        }
      }
    }
    return false;
  }

  void onResolvedFailed(dynamic message) {
    for (var item in resolveEvents) {
      item.onResolvedFailed(message);
    }
  }

  void onError(
    SendMessage message,
    (Object error, StackTrace stackTrace) data,
  ) {
    for (var item in resolveEvents) {
      item.onError(message, data.$1, data.$2);
      return;
    }
  }

  final _listener = <dynamic, StreamSubscriptionOwner>{};

  @protected
  bool remove(dynamic key) {
    if (key is KeyController) {
      if (_listener.containsKey(key.key)) {
        final sub = _listener[key.key];
        switch (key.keyType) {
          case KeyType.cancel:
            _listener.remove(key.key);
            sub?.cancel();
            break;
          case KeyType.pause:
            sub?.pause();
            break;
          case KeyType.resume:
            sub?.resume();
            break;
          default:
            Log.w('error $key');
        }
        return true;
      }
    }

    return false;
  }

  @protected
  void receipt(
    dynamic data,
    SendMessage message, {
    (Object error, StackTrace stackTrace)? error,
  }) {
    assert(error == null || data == null);
    switch (data) {
      case Future data:
        futureAutoSend(data, message);
      case Stream data:
        streamSend(data, message);
      case var _ when error != null:
        sendError(message, error);
        onError(message, error);
      case var data:
        objectSend(data, message);
    }
  }

  @protected
  FutureOr<dynamic> encode(dynamic data) {
    if (data is Uint8List) {
      data = Uint8ListType(data);
    }

    try {
      if (data is TransferType) return data.encode().whenComplete(() => data);
    } catch (_) {}
    return data;
  }

  Future<void> futureAutoSend(Future data, SendMessage m) {
    return data.then(
      (value) async {
        value = await encode(value);
        m.receipt(value);
      },
      onError: (e, s) {
        Log.e('future receive error: $e\n$s');
        sendError(m, (e, s));
      },
    );
  }

  void streamSend(Stream data, SendMessage m) {
    final key = m.uniqueKey;
    final subOwner = StreamSubscriptionOwner();
    StreamSubscription sub;
    sub = data.listen(
      (data) {
        if (subOwner.isCancel) return;
        final encodeData = encode(data);
        EventQueue.push(key, () {
          if (!subOwner.isCancel) {
            return encodeData.then(m.receipt);
          }
        });
      },
      onDone: () {
        _listener.remove(key);
        EventQueue.push(key, () {
          m.receipt(StreamState.done);
        });
      },
      onError: (e, s) {
        _listener.remove(key);
        EventQueue.push(key, () => sendError(m, (e, s)));
      },
      cancelOnError: true,
    );
    subOwner.sub = sub;
    _listener[key] = subOwner;
    assert(Log.i('listeners: ${_listener.length}'));
  }

  void objectSend(Object? data, SendMessage m) {
    encode(data).then(
      (value) => m.receipt(value),
      onError: (e, s) {
        sendError(m, (e, s));
        Log.e('error: $e');
      },
    );
  }

  void sendError(SendMessage m, (Object error, StackTrace stackTrace) error) {
    m.receipt(error, result: Result.failed);
  }
}

class NopUseDynamicVersionExection implements Exception {
  NopUseDynamicVersionExection(this.message);
  final String message;
  @override
  String toString() {
    return '$runtimeType: $message';
  }
}

class StreamSubscriptionOwner {
  StreamSubscriptionOwner();

  late StreamSubscription sub;
  bool _canceled = false;
  bool get isCancel => _canceled;
  Future<void> cancel() {
    _canceled = true;
    return sub.cancel();
  }

  void pause() {
    if (!sub.isPaused) sub.pause();
  }

  void resume() {
    if (sub.isPaused) sub.resume();
  }

  bool get isPaused => sub.isPaused;
}
