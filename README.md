提供一种Isolate编程的解决方案。

## 示例
```dart

part 'isolate_event.g.dart';

@NopServerEvent()
@NopServerEventItem(serverName: 'isolate') // 其他未命名的默认在 'isolate' Isolate 中
abstract class IsolateEvent implements FirstEvent, SecondEvent, ThirdEvent {}

/// 通常会创建一个新的 名为'first_isolate'的 Isolate
@NopServerEventItem(serverName: 'first_isolate')
abstract class FirstEvent {
  FutureOr<bool?> workStatus();
  FutureOr<String?> getBookName(int id);
}

/// 未命名的类会在默认的 Isolate 中
abstract class SecondEvent implements OtherEvents {
  Stream<String?> getStream();
}

/// third_isolate 可以与 'first_isolate' 通信
@NopServerEventItem(
    serverName: 'third_isolate', connectToServer: ['first_isolate'])
abstract class ThirdEvent {
  // function
}

abstract class OtherEvents {
  void doOtherWrok();
}

```

运行 `dart run build_runner build`之后，生成的代码会在 isolate_event.g.dart 文件中

