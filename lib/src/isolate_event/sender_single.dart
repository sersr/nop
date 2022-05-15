import '../event_dispatch/event_dispatch.dart';
import 'message.dart';
import 'send_future_stream_mixin.dart';

/// 共享单一端口
class SenderCompleter<T> with Sender, SenderAddDataMixin<T> {
  SenderCompleter(this.onRemove);
  @override
  OnReomveCallback onRemove;
}

class SenderStreamController<T>
    with Sender, StreamLazyMixin<T>, ListenerControllerStreamMixin<T> {
  SenderStreamController(this.onRemove, this.onSend, this.shouldCache);
  @override
  OnReomveCallback onRemove;
  @override
  KeyControllerCallback onSend;
  @override
  final bool shouldCache;
}
