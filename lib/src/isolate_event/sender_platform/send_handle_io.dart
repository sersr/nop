import 'dart:async';

import 'dart:isolate';

import 'send_handle.dart';
import 'package:equatable/equatable.dart';

class SendIoHandle extends Equatable implements SendHandle {
  @override
  final SendPort sendPort;

  const SendIoHandle(this.sendPort);
  @override
  void send(message) {
    sendPort.send(message);
  }

  @override
  List<Object?> get props => [sendPort];
}

class ReceiveHandleImpl extends Stream implements ReceiveHandle {
  late final ReceivePort _rcPort = ReceivePort();
  @override
  late SendHandle sendHandle = SendIoHandle(_rcPort.sendPort);

  @override
  void close() {
    _rcPort.close();
  }

  @override
  StreamSubscription listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _rcPort.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
