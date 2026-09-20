import '../isolate_event/sender_transfer_data.dart';
import '../isolate_event/send_future_stream_mixin.dart';

class NopServerEvent {
  const NopServerEvent();
}


/// example:
/// 
/// FutureOr<
/// 
/// 
/// see: [TransferType], [SenderAddDataMixin], [ListenerControllerStreamMixin]
class NopServerMethod {
  const NopServerMethod({
    this.transferType,
    this.cached = false,
    this.unique = false,
  });
  final Function? transferType;
  final bool unique;
  final bool cached;
}
