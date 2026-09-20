import 'dart:async';

import 'package:nop/nop.dart';

/// 远程服务/主机
/// 提供[kill]接口

abstract class RemoteServer<T> {
  RemoteServer();

  factory isolate({
    required RemoteEntryPoint<T> entry,
    required T args,
    String? debugName,
  }) = IsolateRemoteServer<T>;

  factory local({
    required RemoteEntryPoint<T> entry,
    required T args,
    String? debugName,
  }) = LocalRemoteServer<T>;

  bool get killed;
  FutureOr<SendHandleName> create(SendHandle rootSendHandle);

  SendHandleName? get lastSendHandle;

  FutureOr<void> kill() {}

  static IsolateResolve? get current {
    if (Zone.current[IsolateResolve] case IsolateResolve resolve?) {
      return resolve;
    }
    return null;
  }
}

/// 由[entry]创建
class LocalRemoteServer<T> extends RemoteServer<T> {
  LocalRemoteServer({required this.entry, required this.args, this.debugName});
  final T args;
  final RemoteEntryPoint<T> entry;
  final String? debugName;

  IsolateResolve? _runner;

  @override
  SendHandleName? get lastSendHandle => _lastSendHandle;

  SendHandleName? _lastSendHandle;
  @override
  FutureOr<SendHandleName> create(SendHandle rootSendHandle) {
    if (_lastSendHandle case var handle?) return handle;

    try {
      final runner = IsolateResolve(
        remoteSendHandle: rootSendHandle,
        resolveRecord: entry(args),
      );
      runner.run();
      _lastSendHandle = runner.currentLocalSendHandle;
      return runner.currentLocalSendHandle;
    } catch (e, s) {
      _runner?.onClose();
      _runner = null;
      _lastSendHandle = null;
      Log.e('local error: $e\n$s');
      rethrow;
    }
  }

  @override
  FutureOr<void> kill() {
    final future = _runner?.onClose();
    _lastSendHandle = null;
    _runner = null;
    return future;
  }

  @override
  bool get killed => _runner == null || _lastSendHandle == null;
}

typedef RemoteEntryPoint<T> = ResolveRecord Function(T args);
