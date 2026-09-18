import 'dart:async';
import 'send_handle_io.dart'
    if (dart.library.js_interop) 'send_handle_web.dart';

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
/// [remoteSendHandle] 出自 <local>的[ReceiveHandle]
// class SendHandleOwner {
//   SendHandleOwner({
//     required this.localSendHandle,
//     required this.remoteSendHandle,
//   });

//   final SendHandle localSendHandle;
//   final SendHandle remoteSendHandle;
// }

class SendHandleName {
  SendHandleName(
    this.sendHandle, {
    this.isRequest = true,
    required this.protocols,
  });
  final List<Type> protocols;

  /// 是否是请求连接，请求放发起，接收方返回 isRequest = false
  final bool isRequest;
  final SendHandle sendHandle;
}

abstract class ReceiveHandle implements Stream {
  factory ReceiveHandle() = ReceiveHandleImpl;
  SendHandle get sendHandle;
  void close();
}
