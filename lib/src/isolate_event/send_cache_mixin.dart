import '../../utils.dart';
import 'event.dart';
import 'message.dart';

mixin SendCacheMixin on SendEvent {
  final _currentPendingEvents = <Object>{};

  @override
  void onResume() {
    if (_currentPendingEvents.isNotEmpty) {
      final events = List.of(_currentPendingEvents);
      assert(Log.i('$runtimeType chache tasks: ${events.length}'));
      _currentPendingEvents.clear();
      events.forEach(send);
    }
    super.onResume();
  }

  @override
  void send(message) {
    if (message is ServerName) {
      final remoteHandle = getRemoteSender(message.protocol);
      if (remoteHandle == null) {
        _currentPendingEvents.add(message);
        return;
      }

      assert(
        _currentPendingEvents.isEmpty ||
            Log.e('_currentPendingEvents ${_currentPendingEvents.length}'),
      );

      if (message is SendMessage) {
        message.reset(localSendHandle);
      }
      remoteHandle.send(message);
      return;
    }

    Log.e('error: $message');
  }
}
