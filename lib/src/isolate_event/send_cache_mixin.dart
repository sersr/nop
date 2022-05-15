import '../../utils.dart';
import 'event.dart';
import 'message.dart';

mixin SendCacheMixin on SendEvent {
  final _currentPendingEvents = <Object>{};

  @override
  void onResume() {
    if (_currentPendingEvents.isNotEmpty) {
      final events = List.of(_currentPendingEvents);
      assert(Log.i('$runtimeType 缓存中的任务数: ${events.length}'));
      _currentPendingEvents.clear();
      events.forEach(send);
    }
    super.onResume();
  }

  @override
  void send(message) {
    if (message is ServerName) {
      final sendHandleOwner = getSendHandleOwner(message.serverName);
      if (sendHandleOwner == null) {
        _currentPendingEvents.add(message);
        return;
      }

      assert(_currentPendingEvents.isEmpty ||
          Log.e('_currentPendingEvents ${_currentPendingEvents.length}'));

      if (message is SendMessage) {
        message.reset(sendHandleOwner.remoteSendHandle);
      }
      sendHandleOwner.localSendHandle.send(message);
      return;
    }

    Log.e('error: $message', onlyDebug: false);
  }
}
