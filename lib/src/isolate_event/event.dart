import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../../utils.dart';
import './message.dart';
import 'sender_transfer_data.dart';

abstract class Messager {
  Future<T> sendMessage<T>(dynamic type, dynamic args,
      {String serverName = 'default'});
  Stream<T> sendMessageStream<T>(dynamic type, dynamic args,
      {bool unique = false,
      bool cached = false,
      String serverName = 'default'});
}

extension SendMessageOption on Messager {
  Future<Option<T>> sendOption<T>(dynamic type, dynamic args,
      {String serverName = 'default'}) {
    return sendMessage(type, args, serverName: serverName).then((value) {
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
    }, onError: (e) => const None());
  }
}

abstract class SendEvent {
  @protected
  bool add(message);

  @protected
  void send(message);

  @mustCallSuper
  @protected
  SendHandleOwner? getSendHandleOwner(String? serverName) => null;
  @mustCallSuper
  @protected
  Map<String, List<Type>> getProtocols() => {};
  @protected
  void notifyState(bool open) {}

  @mustCallSuper
  @protected
  void onResume() {}
  @mustCallSuper
  @protected
  void dispose() {}
}

class ServerConfigurations<T> {
  ServerConfigurations({
    required this.args,
    required this.sendHandle,
  });
  final T args;
  final SendHandle sendHandle;
}

/// 端口创建/监听
/// 初始化
mixin ListenMixin {
  SendHandle get localSendHandle => _rcHandle.sendHandle;

  ServerConfigurations<T> getArgs<T>(T args) =>
      ServerConfigurations(args: args, sendHandle: localSendHandle);

  late ReceiveHandle _rcHandle;
  FutureOr<void> run() async {
    return runZonedGuarded(() => Log.logRun(_initState), (error, stack) {
      Log.e('error: $error\n$stack', lines: 4, position: 2, onlyDebug: false);
    });
  }

  FutureOr<void> onInitStart() {}

  Future<void> _initState() async {
    _rcHandle = ReceiveHandle();
    await onInitStart();
    final any = FutureAny();
    initStateListen(any.add);

    final wait = any.wait;
    if (wait != null) await wait;
    await onListen(_rcHandle);
    onResumeListen();
  }

  @mustCallSuper
  void initStateListen(void Function(FutureOr<void> work) add) {}
  @mustCallSuper
  void onResumeListen() {}

  FutureOr<void> onListen(ReceiveHandle rcHandle) {
    rcHandle.listen(listen);
  }

  @mustCallSuper
  bool listen(message) {
    if (message is SendHandleName) {
      if (!onListenReceivedSendHandle(message)) {
        Log.e('can not resolve ${message.name} sendHandle', onlyDebug: false);
      }
      return true;
    }
    return false;
  }

  void closeRcHandle() {
    _rcHandle.close();
  }

  @mustCallSuper
  bool onListenReceivedSendHandle(SendHandleName sendHandleName) => false;
}

/// 不需要调用[Resolve]的[onResumeListen]
/// 以[SendEvent]为主
mixin SendEventResolve on SendEvent, Resolve {
  @override
  FutureOr<void> onInitStart() {
    resume = true;
    return super.onInitStart();
  }

  @override
  void dispose() {
    resume = false;
    super.dispose();
  }
}

mixin Resolve on ListenMixin {
  SendHandle? get remoteSendHandle;
  Map<Type, List<Function>> resolveFunctionIterable() => {};
  Map<String, List<Type>> getResolveProtocols() => {};

  bool _resume = false;

  set resume(bool v) {
    _resume = v;
  }

  @override
  void onResumeListen() {
    if (remoteSendHandle != null && !_resume) {
      _resume = true;

      final map = <String, Set<Type>>{};
      for (var protocols in getResolveProtocols().entries) {
        final prot = map.putIfAbsent(protocols.key, () => <Type>{});
        prot.addAll(protocols.value);
      }
      for (var item in map.entries) {
        remoteSendHandle!.send(SendHandleName(item.key, localSendHandle,
            protocols: item.value.toList(), isToRemote: false));
      }
    }
    super.onResumeListen();
  }

  @override
  bool listen(message) {
    if (remove(message)) return true;
    final success = resolve(message) || super.listen(message);
    if (!success) {
      onResolvedFailed(message);
    }
    return success;
  }

  @mustCallSuper
  FutureOr<void> onClose() {
    _resume = false;
    // 只有关闭端口，`Isolate`才会退出
    closeRcHandle();
  }

  List<MapEntry<Type, List<Function>>>? _resolveFunctions;

  List<MapEntry<Type, List<Function>>> get _resolves {
    if (_resolveFunctions != null) return _resolveFunctions!;
    return _resolveFunctions ??= resolveFunctionIterable().entries.toList();
  }

  @protected
  bool resolve(message) {
    if (message is SendMessage) {
      final type = message.type;
      for (var item in _resolves) {
        if (identical(type.runtimeType, item.key)) {
          try {
            final result = item.value.elementAt(type.index)(message.args);
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

  void onResolvedFailed(dynamic message) {}

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
            Log.w('error $key', onlyDebug: false);
        }
        return true;
      } else if (key.key is SendHandle &&
          identical(key.keyType, KeyType.closeServer)) {
        final sp = key.key;
        onClose().whenComplete(() => sp
            .send(SendHandleName('${key.serverName}', sp, isToRemote: false)));

        return true;
      }
    }
    return false;
  }

  @protected
  void receipt(o, SendMessage m, [bool isError = false]) {
    var sendHandle = m.sendHandle;
    // 使用独立端口，如果可用
    if (m.uniqueKey is SendHandle) sendHandle = m.uniqueKey as SendHandle;

    if (o is Future) {
      futureAutoSend(o, sendHandle, m);
    } else if (o is Stream) {
      streamSend(o, sendHandle, m);
    } else if (!isError) {
      objectSend(o, sendHandle, m);
    }

    if (isError) {
      sendError(o, sendHandle, m);
      onError(m, (o as (Object, StackTrace)).$1);
    }
  }

  void onError(message, error) {}

  @protected
  FutureOr<void> encode(dynamic data) {
    if (data is TransferType) return data.encode();
  }

  Future<void> futureAutoSend(Future data, SendHandle sp, SendMessage m) {
    return data.then((value) async {
      await encode(value);
      sp.send(ReceiveMessage(data: value, uniqueKey: m.uniqueKey));
    }, onError: (e, s) {
      Log.e('future receive error: $e\n$s',
          lines: 4, position: 1, onlyDebug: false);
      sendError((e, s), sp, m);
    });
  }

  void streamSend(Stream data, SendHandle sp, SendMessage m) {
    final key = m.uniqueKey;
    final hasPrivateHandle = key is SendHandle;
    final subOwner = StreamSubscriptionOwner();
    StreamSubscription sub;
    sub = data.listen((data) {
      if (subOwner.isCancel) return;
      final encodeData = encode(data);
      EventQueue.push(key, () {
        if (!subOwner.isCancel) {
          if (hasPrivateHandle) {
            return encodeData.whenComplete(() => sp.send(data));
          } else {
            final value = ReceiveMessage(data: data, uniqueKey: key);
            return encodeData.whenComplete(() => sp.send(value));
          }
        }
      });
    }, onDone: () {
      _listener.remove(key);
      EventQueue.push(key, () {
        sp.send(ReceiveMessage(data: StreamState.done, uniqueKey: key));
      });
    }, onError: (e, s) {
      _listener.remove(key);
      Log.w('$e\n$s', onlyDebug: false);
      EventQueue.push(key, () => sendError((e, s), sp, m));
    }, cancelOnError: true);
    subOwner.sub = sub;
    _listener[key] = subOwner;
    assert(Log.i('listeners: ${_listener.length}'));
  }

  void objectSend(Object? data, SendHandle sp, SendMessage m) {
    encode(data).then(
        (value) => sp.send(ReceiveMessage(data: data, uniqueKey: m.uniqueKey)),
        onError: (e, s) {
      sendError((e, s), sp, m);
      Log.e('error: $e');
    });
  }

  void sendError(error, SendHandle sp, SendMessage m) {
    assert(error is (Object, StackTrace));
    sp.send(ReceiveMessage(
        data: error, uniqueKey: m.uniqueKey, result: Result.failed));
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
