import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../../utils.dart';
import 'event.dart';
import 'message.dart';

/// 远程服务/主机
/// 提供[kill]接口

abstract class RemoteServer {
  RemoteServer();

  bool get killed;
  FutureOr<SendHandleName> create(SendHandle sendHandle);

  SendHandleName? get lastSendHandle;

  @mustCallSuper
  FutureOr<void> kill() {}
}

/// 由[entryPoint]创建
class LocalRemoteServer<T> extends RemoteServer {
  LocalRemoteServer({
    required this.entryPoint,
    required this.args,
    this.debugName,
  });
  final T args;
  final RemoteEntryPoint<T> entryPoint;
  final String? debugName;

  Runner? _runner;
  FutureOr<SendHandleName>? _createTask;

  @override
  SendHandleName? get lastSendHandle => _lastSendHandle;

  @override
  FutureOr<SendHandleName> create(SendHandle sendHandle) {
    if (_runner != null) {
      if (_lastSendHandle case var handle?) {
        return handle;
      }
    }

    final createNew = _createTask == null;
    final task = _createTask ??= _create(sendHandle);
    if (createNew) {
      task.whenComplete(() => _createTask = null);
    }
    return task;
  }

  SendHandleName? _lastSendHandle;
  FutureOr<SendHandleName> _create(SendHandle sendHandle) {
    if (_lastSendHandle case var handle?) return handle;

    return entryPoint(args).then((runner) {
      _runner = runner;
      return runner.run(sendHandle)..then((v) {
        _lastSendHandle = v;
      });
    });
  }

  @override
  FutureOr<void> kill() {
    _runner?.close();
    _lastSendHandle = null;
    _runner = null;
    super.kill();
  }

  @override
  bool get killed => _runner == null || _lastSendHandle == null;
}

class Runner {
  final FutureOr<T> Function<T>(FutureOr<T> Function())? runDelegate;
  final Resolve runner;
  Runner({required this.runner, this.runDelegate});

  FutureOr<SendHandleName> run(SendHandle sendHandle) {
    Future<SendHandleName> run() => runner.runResolve(sendHandle);
    return runDelegate.mapOption(
      ifNone: run,
      ifSome: (runDelegate) => runDelegate(run),
    );
  }

  void close() {
    runner.close();
  }
}

typedef RemoteEntryPoint<T> = FutureOr<Runner> Function(T args);

/// 通常由其他[RemoteServer]代理时
/// 为其提供一个句柄
class DelegateRemoteServer extends RemoteServer {
  DelegateRemoteServer({required this.remoteSendHandle});
  @override
  bool get killed => false;

  final SendHandleName remoteSendHandle;

  @override
  SendHandleName get lastSendHandle => remoteSendHandle;
  @override
  FutureOr<SendHandleName> create(SendHandle sendHandle) {
    return remoteSendHandle;
  }
}
