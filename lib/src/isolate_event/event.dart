import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../../utils.dart';
import './message.dart';
import 'sender_transfer_data.dart';

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

typedef TaskCallback = Future<void> Function();

final class ResolveItem {
  ResolveItem({
    required this.protocol,
    required this.protocolFns,
    required this.onClose,
    required this.onInit,
  });

  final TaskCallback? onInit;
  final TaskCallback? onClose;
  final Type protocol;
  final List<Function> protocolFns;
}

mixin Resolve {
  SendHandle get localSendHandle => _rcHandle.sendHandle;

  final _rcHandle = ReceiveHandle();

  void Function()? onResolveResume;
  void Function(dynamic message)? onResolveResolvedFailed;
  void Function(dynamic message, dynamic error)? onResolveError;

  final List<ResolveItem> _resolveItems = [];

  void addResolveItem(ResolveItem item) {
    if (_inited) {
      assert(Log.e("current resolve inited."));
      return;
    }
    _resolveItems.add(item);
  }

  void addResolveItemAll(List<ResolveItem> items) {
    if (_inited) {
      assert(Log.e("current resolve inited."));
      return;
    }
    _resolveItems.addAll(items);
  }

  SendHandle? _remoteSendHandle;
  SendHandle? get remoteSendHandle => _remoteSendHandle;

  final _completer = Completer<SendHandle>();
  Future<SendHandle> get remoteSendHandleAsync => _completer.future;

  var _inited = false;
  Future<SendHandleName> runResolve(SendHandle sendHandle) async {
    _remoteSendHandle = sendHandle;
    if (!_completer.isCompleted) {
      _completer.complete(remoteSendHandle);
    }
    _inited = true;
    await run();
    return currentLocalSendHandle;
  }

  List<Type> get protocols => _resolveItems.map((e) => e.protocol).toList();

  SendHandleName get currentLocalSendHandle =>
      SendHandleName(localSendHandle, protocols: protocols, isRequest: false);

  FutureOr<void> run() async {
    return runZonedGuarded(_initState, (error, stack) {
      Log.e('error: $error\n$stack');
    });
  }

  FutureOr<void> Function()? onListenInitStart;
  FutureOr<void> onInitStart() {
    return onListenInitStart?.call();
  }

  Future<void> _initState() async {
    await onInitStart();
    final any = FutureAny();
    for (var e in _resolveItems) {
      any.add(e.onInit?.call());
    }

    final wait = any.wait;
    if (wait != null) await wait;
    _rcHandle.listen(listen);
    onResumeListen();
  }

  @mustCallSuper
  void onResumeListen() {
    onResolveResume?.call();
  }

  bool listen(message) {
    if (remove(message)) return true;
    final success = resolve(message);
    if (!success) {
      onResolvedFailed(message);
    }
    return success;
  }

  void close() {
    onClose();
  }

  void closeRcHandle() {
    _rcHandle.close();
  }

  @mustCallSuper
  FutureOr<void> onClose() {
    _resolveItems
        .map((e) => e.onClose?.call())
        .whereType<Future>()
        .wait
        .whenComplete(() {
          // 只有关闭端口，`Isolate`才会退出
          closeRcHandle();
        });
  }

  @protected
  bool resolve(message) {
    if (message is SendMessage) {
      final type = message.type;
      for (var item in _resolveItems) {
        if (identical(type.runtimeType, item.protocol)) {
          try {
            final result = item.protocolFns.elementAt(type.index)(message.args);
            receipt(result, message);
          } catch (e, stacktrace) {
            receipt((e, stacktrace), message, true);
          }
          return true;
        }
      }
    }
    return false;
  }

  void onResolvedFailed(dynamic message) {
    onResolveResolvedFailed?.call(message);
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
  void receipt(o, SendMessage m, [bool isError = false]) {
    if (o is Future) {
      futureAutoSend(o, m);
    } else if (o is Stream) {
      streamSend(o, m);
    } else if (!isError) {
      objectSend(o, m);
    }

    if (isError) {
      sendError(o, m);
      onError(m, (o as (Object, StackTrace)).$1);
    }
  }

  void onError(message, error) {
    onResolveError?.call(message, error);
  }

  @protected
  FutureOr<void> encode(dynamic data) {
    if (data is TransferType) return data.encode();
  }

  Future<void> futureAutoSend(Future data, SendMessage m) {
    return data.then(
      (value) async {
        await encode(value);
        m.receipt(value);
      },
      onError: (e, s) {
        Log.e('future receive error: $e\n$s');
        sendError((e, s), m);
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
            return encodeData.whenComplete(() => m.receipt(data));
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
        EventQueue.push(key, () => sendError((e, s), m));
      },
      cancelOnError: true,
    );
    subOwner.sub = sub;
    _listener[key] = subOwner;
    assert(Log.i('listeners: ${_listener.length}'));
  }

  void objectSend(Object? data, SendMessage m) {
    encode(data).then(
      (value) => m.receipt(data),
      onError: (e, s) {
        sendError((e, s), m);
        Log.e('error: $e');
      },
    );
  }

  void sendError(error, SendMessage m) {
    assert(error is (Object, StackTrace));
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
