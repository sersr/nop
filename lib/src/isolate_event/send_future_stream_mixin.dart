import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../event_dispatch/event_dispatch.dart';
import 'message.dart';
import 'sender_transfer_data.dart';

typedef OnReomveCallback<T> = void Function(Sender sender);

mixin SenderAddDataMixin<T> on Sender {
  late final completer = Completer<T>();
  OnReomveCallback<T> get onRemove;

  @override
  void addData(dynamic data) {
    dynamic messageData = data;
    if (messageData is TransferType<T>) {
      messageData.decode().then(_complete);
      return;
    } else if (T == dynamic) {
      messageData = materialize(messageData);
    }

    _complete(messageData);
  }

  @override
  void addError(Object error, StackTrace stackTrace) {
    if (nullOnError && null is T) {
      _complete();
    } else {
      completer.completeError(error, stackTrace);
      close();
    }
  }

  @override
  void cancel() {
    if (!completer.isCompleted) {
      completer.completeError('cancel');
      close();
    }
  }

  void _complete([data]) {
    if (!completer.isCompleted) {
      completer.complete(data);
      close();
    }
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
    dynamic messageData = data;
    if (data is StreamState) {
      if (_quque.actived) {
        _quque.addEventTask(close);
      } else {
        close();
      }
      return;
    }
    if (messageData is TransferType<T>) {
      _quque.addEventTask(
        () => messageData.decode().then((value) {
          if (!isCanceled) add(value);
        }),
      );
      return;
    } else if (T == dynamic) {
      messageData = materialize(messageData);
    }
    add(messageData);
  }

  @override
  void addError(Object error, StackTrace stackTrace) {
    if (nullOnError && null is T) {
      close();
    } else {
      super.addError(error, stackTrace);
    }
  }

  @override
  void cancel() {
    close();
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
