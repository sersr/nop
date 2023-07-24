import '../event_dispatch/event_dispatch.dart';
import 'message.dart';
import 'send_future_stream_mixin.dart';

/// 独立端口
mixin SenderPrivateHandle implements Sender {
  final receiveHandle = ReceiveHandle();

  @override
  late final SendHandle identityKey = receiveHandle.sendHandle;
}

class SenderCompleterPrivateHandle<T>
    with
        Sender,
        SenderOnReceivedMixin,
        SenderPrivateHandle,
        SenderAddDataMixin<T> {
  SenderCompleterPrivateHandle(this.onRemove) {
    receiveHandle.first.then(onReceived);
  }
  @override
  final OnReomveCallback onRemove;

  @override
  void close() {
    receiveHandle.close();
    super.close();
  }
}

class SenderStreamPrivateHandle<T>
    with
        Sender,
        SenderOnReceivedMixin,
        SenderPrivateHandle,
        StreamLazyMixin<T>,
        ListenerControllerStreamMixin<T> {
  SenderStreamPrivateHandle(this.onRemove, this.onSend, this.shouldCache) {
    receiveHandle.listen(onReceived);
  }

  @override
  final OnReomveCallback onRemove;
  @override
  final KeyControllerCallback onSend;
  @override
  final bool shouldCache;
}
