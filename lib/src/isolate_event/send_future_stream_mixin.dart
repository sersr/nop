import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../event_dispatch/event_dispatch.dart';
import 'message.dart';
import 'sender_transfer_data.dart';

typedef OnResolveHandle = dynamic Function(dynamic data);
typedef OnReomveCallback<T> = void Function(Sender sender);

mixin SenderAddDataMixin<T> on Sender {
  late final completer = Completer<T>()..future.whenComplete(close);
  OnReomveCallback<T> get onRemove;

  @override
  void addData(dynamic data) {
    dynamic _data = data;
    if (_data is TransferType<T>) {
      _data.decode().then((value) {
        if (!completer.isCompleted) completer.complete(value);
      });
      return;
    } else if (T == dynamic && _data is TransferableTypedData) {
      _data = _data.materialize();
    }
    if (!completer.isCompleted) {
      completer.complete(_data);
    }
  }

  @override
  void cancel() {
    if (!completer.isCompleted) completer.complete();
  }

  Future<T> get future => completer.future;

  @mustCallSuper
  void close() {
    onRemove(this);
  }
}

mixin ListenerControllerStreamMixin<T> on Sender, StreamLazyMixin<T> {
  void Function(Sender) get onRemove;
  KeyControllerCallback get onSend;
  late final _quque = EventQueue();
  @override
  void addData(dynamic data) {
    dynamic _data = data;
    if (data is StreamState) {
      _quque.addEventTask(() {
        if (data == StreamState.done) {
          cancel();
        } else if (data == StreamState.error) {
          cancel();
        }
      });
      return;
    }
    if (_data is TransferType<T>) {
      _quque.addEventTask(
        () => _data.decode().then((value) {
          if (!isCanceled) add(value);
        }),
      );
      return;
    } else if (T == dynamic && _data is TransferableTypedData) {
      _data = _data.materialize();
    }
    add(_data);
  }

  @override
  void notifyClient() {
    onSend(identityKey, isPaused ? KeyType.pause : KeyType.resume, serverName);
  }

  @override
  void dispose() {
    onRemove(this);
    if (!isCanceled) onSend(identityKey, KeyType.cancel, serverName);
    assert(!hasListener);
  }
}
