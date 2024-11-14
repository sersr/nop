import 'dart:async';
import 'send_handle_io.dart' if (dart.library.js_util) 'send_handle_web.dart';

abstract class SendHandle {
  void send(message);
  Object? get sendPort;
}

/// 隔离之间互通信所需要的[SendHandle]s
/// 调用：<loal>发送消息 => [localSendHandle] => <remote>处理消息
///                 => 返回消息 => [remoteSendPort] => <local>接收消息
///
/// [SendHandle]出自[ReceiveHandle]
///
/// 对应关系：
/// [localSendHandle] 出自 <remote>的[ReceiveHandle]
/// [remoteSendHandle] 出自 <local>的[RecieveHandle]
class SendHandleOwner {
  SendHandleOwner(
      {required this.localSendHandle, required this.remoteSendHandle});

  final SendHandle localSendHandle;
  final SendHandle remoteSendHandle;
}

class SendHandleName {
  SendHandleName(this.name, this.sendHandle,
      {this.protocols, this.isToRemote = true});
  final String name;

  /// true: 由local 发送给 remote
  /// false: remote 返回给 local
  final bool isToRemote;
  final SendHandle sendHandle;
  final List<Type>? protocols;
}

abstract class ReceiveHandle implements Stream {
  factory ReceiveHandle() = ReceiveHandleImpl;
  SendHandle get sendHandle;
  void close();
}
