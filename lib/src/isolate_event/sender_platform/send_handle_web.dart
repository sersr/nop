import 'dart:async';

import 'package:equatable/equatable.dart';

import 'send_handle.dart';

class SendWebHandle extends Equatable implements SendHandle {
  final EventSink sink;
  const SendWebHandle(this.sink);

  @override
  void send(message) {
    sink.add(message);
  }

  @override
  Object? get sendPort => null;

  @override
  List<Object?> get props => [sink];
}

class ReceiveHandleImpl extends Stream implements ReceiveHandle {
  late final StreamController _controller = StreamController();

  @override
  late final SendHandle sendHandle = SendWebHandle(_controller);

  @override
  void close() {
    _controller.close();
  }

  @override
  StreamSubscription listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
