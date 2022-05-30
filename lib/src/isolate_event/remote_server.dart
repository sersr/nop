import 'dart:async';
import 'dart:isolate';

import 'event.dart';
import '../../event_queue.dart';
import '../../utils.dart';
import 'package:meta/meta.dart';

/// 远程服务/主机
/// 提供[kill]接口

abstract class RemoteServer {
  const RemoteServer();

  bool get killed;
  FutureOr<void> create();
  FutureOr<void> kill();
}

/// 不是由当前的对象创建的[RemoteServer]
/// 由用户管理生命周期
class RemoteServerBase extends RemoteServer {
  @override
  @mustCallSuper
  void create() {
    _killed = false;
  }

  @override
  bool get killed => _killed;
  bool _killed = false;
  @override
  void kill() {
    _killed = true;
  }
}

/// 由[entryPoint]创建
class LocalRemoteServer<T> extends RemoteServerBase {
  LocalRemoteServer({required this.entryPoint, required this.args});
  final ServerConfigurations<T> args;
  final RemoteEntryPoint<T> entryPoint;

  @override
  void create() {
    super.create();
    entryPoint(args).then((runner) => runner.run());
  }
}

class Runner {
  final void Function(void Function())? runDelegate;
  final ListenMixin runner;
  Runner({
    required this.runner,
    this.runDelegate,
  });

  void run() {
    runDelegate.mapOption(
      ifNone: runner.run,
      ifSome: (runDelegate) => runDelegate(runner.run),
    );
  }
}

typedef RemoteEntryPoint<T> = FutureOr<Runner> Function(
    ServerConfigurations<T> args);

class _IsolateCreaterWithArgs<T> {
  final ServerConfigurations<T> args;
  final RemoteEntryPoint<T> entryPoint;
  _IsolateCreaterWithArgs(this.entryPoint, this.args);
  FutureOr<void> apply() => entryPoint(args).then((runner) => runner.run());
}

/// 创建一个[Isolate]
class IsolateRemoteServer<T> extends RemoteServer {
  IsolateRemoteServer(
      {required this.entryPoint, required this.args, this.debugName});
  final ServerConfigurations<T> args;
  final RemoteEntryPoint<T> entryPoint;
  final String? debugName;

  Isolate? _isolate;
  @override
  Future<void> create() async {
    _isolate ??= await Isolate.spawn(
        _nopIsolate, _IsolateCreaterWithArgs(entryPoint, args),
        debugName: debugName);
  }

  @override
  bool get killed => _isolate == null;
  @override
  void kill() {
    if (_isolate != null) {
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  static void _nopIsolate(_IsolateCreaterWithArgs args) => args.apply();
}

/// 通常由其他[RemoteServer]代理时
/// 为其提供一个句柄
class NullRemoteServer extends RemoteServer {
  const NullRemoteServer._();
  factory NullRemoteServer() => const NullRemoteServer._();
  @override
  bool get killed => true;

  @override
  void create() {}
  @override
  void kill() {}
}
