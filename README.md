### Isolate.

#### example
```dart

part 'isolate_event.g.dart';

@NopServerEvent()
@NopServerEventItem(serverName: 'isolate')
abstract class IsolateEvent implements FirstEvent, SecondEvent, ThirdEvent {}

@NopServerEventItem(serverName: 'first_isolate')
abstract class FirstEvent {
  FutureOr<bool?> workStatus();
  FutureOr<String?> getBookName(int id);
}

abstract class SecondEvent implements OtherEvents {
  Stream<String?> getStream();
}

@NopServerEventItem(
    serverName: 'third_isolate', connectToServer: ['first_isolate'])
abstract class ThirdEvent {
  // function
}

abstract class OtherEvents {
  void doOtherWrok();
}

```

    dart run build_runner build --delete-conflicting-outputs

