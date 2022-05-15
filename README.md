        提供一种Isolate编程的解决方案。

其中包含的组件：
- isolate_event: 使用Isolate变得更加简单
- event_queue: 事件队列
- nop_db: 以编程的方式写Sql语句，提供监听方式

## isolate_event

### example
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

运行 `dart run build_runner build`之后，生成的代码会在 isolate_event.g.dart 文件中，


# event_queue

基本实现是一个任务队列，提供`await`互斥

```dart
void main() async {
  final fq = FutureQueue();
  thenAwait(fq);
  thenAwait(fq);
  // ...
  await customFutureFunction();
  // ...
  // 等待任务都结束
  await fq.runner;
}

/// 一些对数据比较敏感的操作需要放在一个队列中
/// 不会互相干扰
void thenAwait(FutureQueue fq)async {
  print('start.....');
  // 自动进入队列
  final wait = await fq.wait;
  print('running...');
  // 在任务队列中
  // ...
  await customFutureFunction();
  // ...
  print('end.......');
  // 在任务队列中
  wait.done;
}


Future<void> customFutureFunction() async {
  await Future.delayed(Duration.zero);
  print('....... other..');
}
```
利用dart语言`await`功能，自动包裹`Function`,实现`then`方法，将`Function`安排进入队列中，由于语言特性，需要调用`done`当前任务才真正算是完成了，这样中间的异步也会被包裹进入队列中；  
如果手动调用`then`方法，则无需调用`done`，会自动判断是否手动； 

还有`only`,`onlyWait`方法：
```dart
void main() async {
  final fq = FutureQueue();
  only(fq);
  onlyWait(fq);

  await fq.runner;
  
}

Future<void> only(FutureQueue fq) async {
  // 如果返回`true`意味着可以返回，是被忽略的
  if(await fq.only) return;
  // ...
  // note: 如果之后遇到`await`异步，则需要再次判断
  // ...
}

Future<void> onlyWait(FutureQueue fq) async {
  final onlyWait = await fq.onlyWait;
  // ...
  // 虽然在这中间可以正常使用包括`await`异步
  // 但是最好紧跟着判断条件
  if(onlyWait.doneIfIgnore) {
    // 已经完成`done`,可以正常返回
    return;
  }
  // ...
  onlyWait.done;
}
```
可以看出这两个方法在异步等待之后会提供一些信息，能够判断是否需要中断执行；
