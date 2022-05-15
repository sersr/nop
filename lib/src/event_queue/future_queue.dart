import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../nop.dart';

abstract class FutureQueue with FutureQueueMixin {
  FutureQueue._();

  factory FutureQueue({Object? globalKey, int channels = 1}) {
    if (globalKey != null) {
      return FutureQueueGlobal(globalKey: globalKey, channels: channels);
    }
    return FutureQueueImpl(channels: channels);
  }
  factory FutureQueue.all({Object? globalKey}) {
    return FutureQueue(globalKey: globalKey, channels: -1);
  }

  static void Function(Object error, StackTrace stackTrace)? catchErrorHandler;
}

class FutureQueueImpl extends FutureQueue {
  FutureQueueImpl({int channels = 1})
      : _eventQueue = EventQueue(channels: channels),
        super._();
  final EventQueue _eventQueue;
  @override
  S runTask<S>(S Function(EventQueue) callback) {
    return callback(_eventQueue);
  }

  @override
  Stream asStream() {
    return _eventQueue.stream;
  }

  @override
  Future? get runner => _eventQueue.runner;
  @override
  bool get actived => _eventQueue.actived;
}

class FutureQueueGlobal extends FutureQueue with EquatableMixin {
  FutureQueueGlobal({required this.globalKey, this.channels = 1}) : super._();
  final int channels;
  final Object globalKey;

  @override
  S runTask<S>(S Function(EventQueue) callback) {
    return EventQueue.runTask(globalKey, callback, channels: channels);
  }

  @override
  Future? get runner {
    return EventQueue.getQueueRunner(globalKey);
  }

  @override
  bool get actived {
    return EventQueue.getQueueState(globalKey);
  }

  @override
  Stream asStream() {
    return EventQueue.getQueueStream(globalKey) ?? Stream.value(null);
  }

  @override
  List<Object?> get props => [globalKey, channels];
}

abstract class FutureTask<T> implements Future<T> {
  FutureTask._({required this.delegate});

  final FutureQueueMixin delegate;

  bool get only => false;

  @override
  @protected
  Stream<T> asStream() => Stream.value(currentValue);
  Stream<dynamic> get stream => delegate.asStream();

  @override
  @protected
  Future<T> catchError(Function onError,
          {bool Function(Object error)? test}) async =>
      currentValue;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError, bool waitThis = true}) {
    return delegate.thenAwait<R>(this,
        () => onValue(currentValue).then((value) => value, onError: onError));
  }

  T? _cache;
  T get currentValue => _cache ??= getCurrentValue();

  T getCurrentValue();

  @override
  @protected
  Future<T> timeout(Duration timeLimit,
          {FutureOr<void> Function()? onTimeout}) async =>
      currentValue;

  @override
  @protected
  Future<T> whenComplete(FutureOr<void> Function() action) async {
    return action().then((_) => currentValue, onError: (_) => currentValue);
  }
}

class FutureTaskImpl extends FutureTask<void> {
  FutureTaskImpl({required FutureQueueMixin delegate})
      : super._(delegate: delegate);

  @override
  void getCurrentValue() {}
}

class FutureOnlyTask extends FutureTask<bool> {
  FutureOnlyTask({required FutureQueueMixin delegate})
      : super._(delegate: delegate);
  @override
  bool get only => true;

  @override
  bool getCurrentValue() => FutureQueueMixin.onlyIgnore;
}

mixin FutureQueueMixin {
  @protected
  S runTask<S>(S Function(EventQueue) callback);

  Future? get runner;

  bool get actived;

  Stream<dynamic> asStream();

  Future<void> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return Future<void>.value();
  }

  /// 示例:
  ///
  /// ```dart
  /// final fq = FutureQueue();
  /// final wait = await fq.wait;
  /// final future = await futureFunc().catchs;
  /// // ...
  /// ```
  Future<void> get wait => _wait;

  late final FutureTaskImpl _wait = FutureTaskImpl(delegate: this);

  Future<bool> get only => _only;

  late final _only = FutureOnlyTask(delegate: this);

  bool get shouldIgnore => onlyIgnore;

  /// 检查是否可以忽略当前任务
  static bool get onlyIgnore {
    final result = Zone.current[_ignoreSymbol];
    if (result is bool) return result;

    return false;
  }

  static final _ignoreSymbol = Object();
  static final _futureQueue = Object();

  static FutureTask? get currentTask {
    final task = Zone.current[_futureQueue];
    if (task is FutureTask) return task;
    return null;
  }

  Future<R> thenAwait<R>(FutureTask task, FutureOr<R> Function() onValue) {
    return _run(onValue, task);
  }

  Future<R> _run<R>(FutureOr<R> Function() action, FutureTask task) {
    return runTask((eventQueue) async {
      Log.i('...enter...');
      Map zoneValues = {
        _futureQueue: task,
        if (task.only)
          thenAwaitToken: () =>
              runZoned(action, zoneValues: {_ignoreSymbol: true}),
      };

      return runZoned(() {
        if (task.only) {
          return eventQueue.awaitOne(action);
        }
        return eventQueue.awaitTask(action);
      }, zoneValues: zoneValues) as Future<R>;
    });
  }

  Future<void> timeout(Duration timeLimit,
      {FutureOr<void> Function()? onTimeout}) {
    return Future.value(runner).timeout(timeLimit, onTimeout: onTimeout);
  }

  Future<void> whenComplete(FutureOr<void> Function() action) {
    return Future.value(runner).whenComplete(action);
  }

  Future<R?> runOne<R>(EventCallback<R> action, {Object? taskKey}) {
    return runTask((eventQueue) {
      return eventQueue.awaitOne(action, taskKey: taskKey);
    });
  }

  Future<R> run<R>(EventCallback<R> action, {Object? taskKey}) {
    return runTask((eventQueue) {
      return eventQueue.awaitTask(action, taskKey: taskKey);
    });
  }

  void push<R>(EventCallback<R> action, {Object? taskKey}) {
    runTask((eventQueue) {
      eventQueue.addEventTask(action, taskKey: taskKey);
    });
  }

  void pushOne<R>(EventCallback<R> action, {Object? taskKey}) {
    runTask((eventQueue) {
      eventQueue.addOneEventTask(action, taskKey: taskKey);
    });
  }
}

/// 从当前对象获取全局的[FutureQueue]
extension FtureQueueExt on Object {
  FutureQueue get fqGlobal {
    return FutureQueue(globalKey: this);
  }

  FutureQueue get fqGlobalAll {
    return FutureQueue(globalKey: this, channels: -1);
  }
}

/// 将当前[Future]对象推进[FutureQueue]中
extension FutureCatchs<T> on Future<T> {
  Future<T> get catchs {
    final task = FutureQueueMixin.currentTask;
    Log.e(
        '${EventQueue.currentTask?.hashCode}  ${FutureQueueMixin.currentTask?.hashCode}');
    if (task != null) {
      return _create(task);
    }
    return this;
  }

  Future<T> _create(FutureTask task) {
    Object? ce;
    StackTrace? cs;

    final n = catchError((e, s) {
      ce = e;
      cs = s;
    });

    final completer = Completer<T>();
    return task.then((_) {
      n.whenComplete(() {
        if (ce != null && cs != null) {
          completer.completeError(ce!, cs);
        } else {
          completer.complete(n);
        }
      });
      return completer.future;
    });
  }

  Future<T> get catchsWait {
    final task = FutureQueueMixin.currentTask;
    if (task != null) {
      return _create(task.delegate._wait);
    }
    return this;
  }

  Future<T> get catchsOnly {
    final task = FutureQueueMixin.currentTask;
    if (task != null) {
      return _create(task.delegate._only);
    }
    return this;
  }
}
