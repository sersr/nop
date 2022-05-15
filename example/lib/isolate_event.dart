import 'dart:async';

import 'package:nop/nop.dart';

part 'isolate_event.g.dart';

@NopServerEvent()
@NopServerEventItem(
  serverName: 'isolate',
  connectToServer: ['first_isolate'],
) // 其他未命名的默认在 'isolate' Server 中
abstract class IsolateEvent
    implements FirstEvent, SecondEvent, ThirdEvent, Sec {}

/// 通常会创建一个新的 名为'first_isolate'的 Isolate
@NopServerEventItem(serverName: 'first_isolate', separate: true)
abstract class FirstEvent {
  /// 返回类型为nullable
  FutureOr<bool?> workStatus();
  FutureOr<String?> getBookName(int id);
}

/// 未命名的类会在默认的 Server 中
abstract class SecondEvent implements SecondOtherEvent {
  Stream<String?> getStream();
}

/// third_isolate 可以与 'first_isolate' 通信
@NopServerEventItem(
    serverName: 'third_isolate', connectToServer: ['first_isolate', 'sec'])
abstract class ThirdEvent implements OtherEvents {
  // function
  // Future<void> aas();
}

abstract class SecondOtherEvent {
  FutureOr<void> doSecondOtherWork();
}

abstract class OtherEvents {
  FutureOr<void> doOtherWorks();
}

@NopServerEventItem(isLocal: true, serverName: 'sec')
abstract class Sec {
  FutureOr<bool?> ss();
}
