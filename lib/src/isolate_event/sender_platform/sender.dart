import '../message.dart';
import '../sender_private_handle.dart';

export 'send_handle.dart';
export 'sender_io.dart' if (dart.library.js_interop) 'sender_web.dart';
// export 'sender_web.dart' if (dart.library.js_interop) 'sender_io.dart';

mixin Sender {
  void addData(data);
  void addError(Object error, StackTrace stackTrace);
  void cancel();
  late final Object identityKey = createIdentityKey();
  Object? messageKey;
  Type? protocol;

  bool nullOnError = false;
}

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
      assert(
        sender is SenderStreamPrivateHandle ||
            sender is SenderCompleterPrivateHandle,
      );
      sender.addData(message);
    }
  }
}
