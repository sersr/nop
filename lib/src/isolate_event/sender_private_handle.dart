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
    with Sender, SenderPrivateHandle, SenderAddDataMixin<T> {
  SenderCompleterPrivateHandle(this.onRemove, this.onResolve) {
    receiveHandle.first.then(addData);
  }
  @override
  final OnReomveCallback onRemove;
  final OnResolveHandle onResolve;

  @override
  void addData(dynamic data) {
    dynamic messasgeData = onResolve(data);
    super.addData(messasgeData);
  }

  @override
  void close() {
    receiveHandle.close();
    super.close();
  }
}

class SenderStreamPrivateHandle<T>
    with
        Sender,
        SenderPrivateHandle,
        StreamLazyMixin<T>,
        ListenerControllerStreamMixin<T> {
  SenderStreamPrivateHandle(
      this.onRemove, this.onSend, this.onResolve, this.shouldCache) {
    receiveHandle.listen(addData);
  }

  @override
  final OnReomveCallback onRemove;
  final OnResolveHandle onResolve;
  @override
  final KeyControllerCallback onSend;
  @override
  final bool shouldCache;

  @override
  void addData(dynamic data) {
    dynamic messageData = onResolve(data);
    super.addData(messageData);
  }
}
