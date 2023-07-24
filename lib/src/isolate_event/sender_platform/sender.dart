import '../message.dart';
import '../sender_private_handle.dart';

export 'send_handle.dart';
export 'sender_io.dart' if (dart.library.html) 'sender_web.dart';

mixin SenderOnReceivedMixin on Sender {
  void onReceived(message) {
    onSenderReceived(this, message);
  }

  static void onSenderReceived(Sender sender, message) {
    if (message is ReceiveMessage) {
      switch (message.data) {
        case (Object, StackTrace) data when message.result == Result.failed:
          sender.addError(data.$1, data.$2);
        case var data:
          sender.addData(data);
      }
    } else {
      assert(sender is SenderStreamPrivateHandle);
      sender.addData(message);
    }
  }
}
