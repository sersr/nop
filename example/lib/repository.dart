import 'dart:async';
import 'isolate_event.dart';
import 'package:nop/nop.dart';

class Repository extends MultiIsolateMessagerMain
    with SendCacheMixin, SendInitCloseMixin {
  @override
  RemoteServer get firstIsolateRemoteServer => IsolateRemoteServer(
      entryPoint: firstIsolateEntryPoint, args: getArgs(null));

  @override
  RemoteServer get isolateRemoteServer =>
      IsolateRemoteServer(entryPoint: isolateEntryPoint, args: getArgs(null));

  @override
  RemoteServer get thirdIsolateRemoteServer => IsolateRemoteServer(
      entryPoint: thirdIsolateEntryPoint, args: getArgs(null));

  @override
  SendHandle? get remoteSendHandle => null;

  @override
  FutureOr<bool?> ss() {
    return true;
  }
}

Runner firstIsolateEntryPoint(ServerConfigurations<void> configurations) =>
    Runner(runner: FirstIsolateImpl(configurations: configurations));

class FirstIsolateImpl extends MultiFirstIsolateResolveMain {
  FirstIsolateImpl({required ServerConfigurations configurations})
      : super(configurations: configurations);

  @override
  FutureOr<String?> getBookName(int id) {
    return 'getBookName';
  }

  @override
  FutureOr<bool?> workStatus() {
    return true;
  }
}

Runner thirdIsolateEntryPoint(ServerConfigurations configurations) =>
    Runner(runner: ThridIsolateImpl(configurations: configurations));

class ThridIsolateImpl extends MultiThirdIsolateResolveMain {
  ThridIsolateImpl({required ServerConfigurations configurations})
      : super(configurations: configurations);

  @override
  FutureOr<void> doOtherWorks() async {
    Log.w('$runtimeType: doOtherWorks');
    final fromLocal = await ss();
    Log.w('receive value: $fromLocal');
  }
}

Runner isolateEntryPoint(ServerConfigurations configurations) =>
    Runner(runner: IsolateImpl(configurations: configurations));

class IsolateImpl extends MultiIsolateResolveMain {
  IsolateImpl({required ServerConfigurations configurations})
      : super(configurations: configurations);

  @override
  FutureOr<void> doSecondOtherWork() async {
    // 可以调用 firstIsolate
    final bookName = await getBookName(11);
    final status = await workStatus();
    Log.w('bookName: $bookName, status: $status');
  }

  @override
  Stream<String?> getStream() {
    throw UnimplementedError();
  }
}
