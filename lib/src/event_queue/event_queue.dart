import 'dart:async';
import 'dart:collection';

import 'package:equatable/equatable.dart';

import '../../utils.dart';
import 'future_any.dart';
import 'future_or.dart';

final _zoneToken = Object();
final thenAwaitToken = Object();

/// [TaskEntry._run]
typedef EventCallback<T> = FutureOr<T> Function();
typedef EventRunCallback<T> = Future<void> Function(TaskEntry<T> task);

/// 以队列的形式进行并等待异步任务
///
/// 目的: 确保任务之间的安全性
class EventQueue {
  EventQueue({this.channels = 1});

  ///所有任务即时运行，[channels] 无限制
  EventQueue.all() : channels = -1;
  final int channels;

  static TaskEntry? get currentTask {
    final task = Zone.current[_zoneToken];
    if (task is TaskEntry) return task;
    return null;
  }

  static final _tempQueues = <Object, EventQueue>{};
  static int delayRemove = 5000;

  static S runTask<S>(key, S Function(EventQueue event) run,
      {int channels = 1}) {
    final listKey = _TaskKeys(key, channels);

    final queue =
        _tempQueues.putIfAbsent(listKey, () => EventQueue(channels: channels));
    return run(queue)
      ..whenComplete(() {
        queue.runner.whenComplete(() {
          Timer(Duration(milliseconds: delayRemove.maxThan(0)), () {
            final cache = _tempQueues[listKey];
            if (!queue.actived && cache == queue) {
              _tempQueues.remove(listKey);
            }
          });
        });
      });
  }

  /// 拥有相同的[key]在会一个队列中
  ///
  /// 如果所有任务都已完成，移除[EventQueue]对象
  static Future<T> run<T>(key, EventCallback<T> task, {int channels = 1}) {
    return runTask(key, (event) => event.awaitTask(task), channels: channels);
  }

  static Future<T?> runOne<T>(key, EventCallback<T> task, {int channels = 1}) {
    return runTask(key, (event) => event.awaitOne(task), channels: channels);
  }

  static void push<T>(key, EventCallback<T> task, {int channels = 1}) {
    return runTask(key, (event) => event.addEventTask(task),
        channels: channels);
  }

  static void pushOne<T>(key, EventCallback<T> task, {int channels = 1}) {
    runTask(key, (event) => event.addOneEventTask(task), channels: channels);
  }

  static Future<void> getQueueRunner(key, {int channels = 1}) {
    final listKey = _TaskKeys(key, channels);
    return _tempQueues[listKey]?.runner ?? Future.value(null);
  }

  static bool getQueueState(key, {int channels = 1}) {
    final listKey = _TaskKeys(key, channels);
    return _tempQueues[listKey]?.actived ?? false;
  }

  static Stream? getQueueStream(key, {int channels = 1}) {
    final listKey = _TaskKeys(key, channels);
    return _tempQueues[listKey]?.stream;
  }

  static int checkTempQueueLength() {
    return _tempQueues.length;
  }

  final _taskPool = ListQueue<TaskEntry>();

  bool get isLast => _taskPool.isEmpty;

  Future<T> _addEventTask<T>(EventCallback<T> callback,
      {bool onlyLastOne = false, Object? taskKey}) {
    final task = TaskEntry<T>(
      queue: this,
      taskKey: taskKey,
      callback: callback,
      onlyLast: onlyLastOne,
    );

    _taskPool.add(task);

    final key = task.taskKey;
    final future = task.future;
    if (key != null) {
      final taskList = _taskKeyGroups.putIfAbsent(key, () => <TaskEntry>{});
      if (taskList.isEmpty) {
        task._taskIgnore = _TaskIgnore(true);
      } else {
        assert(taskList.first._taskIgnore != null);
        task._taskIgnore = taskList.first._taskIgnore;
      }
      taskList.add(task);
      future.whenComplete(() {
        taskList.remove(task);
        if (taskList.isEmpty) {
          _taskKeyGroups.remove(key);
        }
      });
    }
    _start();
    return future;
  }

  void addEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask(callback, taskKey: taskKey);

  Future<T> awaitTask<T>(EventCallback<T> callback, {Object? taskKey}) {
    return _awaitTask<T>(callback, taskKey: taskKey);
  }

  Future<T> _awaitTask<T>(EventCallback<T> callback,
      {Object? taskKey, bool onlyLastOne = false}) {
    if (doNotEnterQueue()) {
      final localTask = currentTask!;
      final completer = Completer<T>();
      bool? outer;
      final zone = Zone.current;

      void onError(error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }

      void onValue(value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      }

      void run() {
        zone.run(callback).then(onValue, onError: onError);
      }

      scheduleMicrotask(() {
        if (!localTask._completed && outer == null && !completer.isCompleted) {
          outer = true;
          run();
        }
      });
      // 安排一个傀儡任务进入队列
      _addEventTask(() {
        if (outer == null && !completer.isCompleted) {
          run();
          outer = false;
        }
        return completer.future;
      }, taskKey: taskKey, onlyLastOne: onlyLastOne)
          .then(onValue, onError: onError);

      return completer.future;
    }

    return _addEventTask(callback, onlyLastOne: onlyLastOne, taskKey: taskKey);
  }

  /// 如果任务队列中有多个任务，那么只会保留最后一个任务。
  ///
  /// 例外:
  /// 如果即将要运行的任务与队列中最后一个任务拥有相同的[taskKey]，也不会被抛弃，并且会更改
  /// 状态，如果两个key相等(==)会共享一个状态([_TaskIgnore])，由共享状态决定是否被抛弃,
  /// 每次任务调用开始时，会自动检查与最后一个任务是否拥有相同的[taskKey]，并更新状态。
  void addOneEventTask<T>(EventCallback<T> callback, {Object? taskKey}) =>
      _addEventTask<T?>(callback, onlyLastOne: true, taskKey: taskKey);

  /// 返回的值可能为 null
  Future<T?> awaitOne<T>(EventCallback<T> callback, {Object? taskKey}) {
    return _awaitTask<T?>(callback, taskKey: taskKey, onlyLastOne: true);
  }

  /// 内部实现依赖[TaskEntry]的future，
  /// 如果满足下面条件就不能进入任务队列
  @pragma('vm:prefer-inline')
  bool doNotEnterQueue() {
    final localTask = currentTask;
    if (localTask != null) {
      if (_state == _ChannelState.limited) {
        var length = localTask._eventQueue._tasks.length;
        if (localTask._completed) length--;

        return length >= channels;
      }
      return _state == _ChannelState.one &&
          _isCurrentQueueAndNotCompleted(this);
    }
    return false;
  }

  @pragma('vm:prefer-inline')
  static bool _isCurrentQueueAndNotCompleted(EventQueue currentQueue) {
    final localTask = currentTask;
    return localTask?._eventQueue == currentQueue && !localTask!._completed;
  }

  /// 自动选择要调用的函数
  late final EventRunCallback _runImpl = _getRunCallback();
  late final _ChannelState _state = _getState();
  _ChannelState _getState() {
    if (channels < 1) {
      return _ChannelState.run;
    } else if (channels > 1) {
      return _ChannelState.limited;
    } else {
      return _ChannelState.one;
    }
  }

  EventRunCallback _getRunCallback() {
    switch (_state) {
      case _ChannelState.limited:
        return _limited;
      case _ChannelState.run:
        return _runAll;
      default:
        return runEvent;
    }
  }

  final _tasks = FutureAny();
  final _taskKeyGroups = <Object, Set<TaskEntry>>{};

  static Future<void> runEvent(TaskEntry task) => task._runZone();

  Future<void> _limited(TaskEntry task) async {
    _tasks.add(runEvent(task));

    // 达到 channels 数              ||  最后一个
    while (_tasks.length >= channels || _taskPool.isEmpty) {
      if (_tasks.isEmpty) break;
      await _tasks.any;
      await idleWait;
    }
  }

  Future<void> _runAll(TaskEntry task) async {
    _tasks.add(runEvent(task));

    if (_taskPool.isEmpty) {
      while (_tasks.isNotEmpty) {
        if (_taskPool.isNotEmpty) break;
        await _tasks.any;
        await idleWait;
      }
    }
  }

  Future<void>? _runner;
  Future<void>? get runner =>
      _isCurrentQueueAndNotCompleted(this) ? null : _runner;

  bool _active = false;
  bool get actived => _active;
  void _start() {
    if (_active) return;
    _runner = _run();
  }

  /// 依赖于事件循环机制
  ///
  /// 执行任务队列
  Future<void> _run() async {
    _active = true;
    while (_taskPool.isNotEmpty) {
      final task = _taskPool.removeFirst();

      /// 处理忽略逻辑
      if (task.onlyLast && !isLast) {
        final taskKey = task.taskKey;
        if (taskKey != null) {
          assert(_taskKeyGroups.containsKey(taskKey));
          final taskList = _taskKeyGroups[taskKey]!;

          final last = _taskPool.last;

          final first = taskList.first;
          assert(first._taskIgnore != null);
          final ignore = last.taskKey != task.taskKey;
          first._ignore(ignore);
        }
      }
      await _runImpl(task);
      await idleWait;
    }
    _active = false;
    _closeStream();
  }

  StreamController? _streamController;
  Stream get stream {
    if (!_active) return Stream.value(null);
    if (_streamController != null) return _streamController!.stream;
    _streamController = StreamController.broadcast(onCancel: _closeStream);
    return _streamController!.stream;
  }

  void _addToStream(dynamic data) {
    if (_streamController != null) {
      _streamController!.add(data);
    }
  }

  void _addErrorToStream(dynamic error, stackTrace) {
    if (_streamController != null) {
      _streamController!.addError(error, stackTrace);
    }
  }

  void _closeStream() {
    if (_streamController != null) {
      _streamController!.close();
      _streamController = null;
    }
  }
}

class TaskEntry<T> {
  TaskEntry({
    required this.callback,
    required EventQueue queue,
    this.taskKey,
    this.isOvserve = false,
    this.onlyLast = false,
  })  : _eventQueue = queue,
        _zone = Zone.current;
  final Zone _zone;
  final bool isOvserve;

  /// 此任务所在的事件队列
  final EventQueue _eventQueue;

  /// 具体的任务回调
  final EventCallback<T> callback;

  EventCallback<T>? get thenAwait {
    final thenAwaitCallback = _zone[thenAwaitToken];
    if (thenAwaitCallback is EventCallback<T>) return thenAwaitCallback;
    return null;
  }

  /// 可通过[EventQueue.currentTask]访问、修改；
  /// 作为数据、状态等
  dynamic value;

  final Object? taskKey;

  /// [onlyLast] == true 并且不是任务队列的最后一个任务，才会被抛弃
  /// 不管 [onlyLast] 为任何值，最后一个任务都会执行
  final bool onlyLast;

  bool get canDiscard => !_eventQueue.isLast && onlyLast && ignoreOrNull;
  bool get ignore => _taskIgnore?.ignore == true;
  bool get ignoreOrNull => _taskIgnore?.ignore == null || ignore;

  bool get notIgnoreOrNull => !ignore;

  bool get notIgnore => !onlyLast || _taskIgnore?.ignore == false;
  void _ignore(bool v) {
    _taskIgnore?.ignore = v;
  }

  bool isCurrentQueue(EventQueue queue) {
    return _eventQueue == queue;
  }

  // 共享一个对象
  _TaskIgnore? _taskIgnore;

  // 队列循环要等待的对象
  Completer<void>? _innerCompleter;

  Future<void> _runZone() {
    return _zone.fork(zoneValues: {_zoneToken: this}).run(_run);
  }

  Future<void> _run() async {
    if (notIgnore || _eventQueue.isLast) {
      try {
        assert(_innerCompleter == null);
        _innerCompleter ??= Completer<void>();
        callback().then(_completeAll, onError: _completeErrorAll);
        return _innerCompleter?.future;
      } catch (e, s) {
        _completedError(e, s);
      }
    } else {
      final local = thenAwait;
      if (local != null) {
        /// 一旦进入到这里，[addLast] 无法使用
        return local().then(_complete, onError: _completedError);
      } else {
        _complete();
      }
    }
  }

  /// 从 [EventQueue.currentTask] 访问
  void addLast() {
    assert(!_completed);
    assert(EventQueue.currentTask != null);
    if (_innerCompleter == null || thenAwait != null) return;

    _innerComplete();
    _eventQueue
      .._taskPool.add(this)
      .._start();
  }

  final _outCompleter = Completer<T>();

  Future<T> get future => _outCompleter.future;

  bool _completed = false;

  /// [result] == null 的情况
  ///
  /// 1. [T] 为 void 类型
  /// 2. [onlyLast] == true 且被抛弃忽略
  @pragma('vm:prefer-inline')
  void _complete([T? result]) {
    if (_completed) return;

    _completed = true;
    _outCompleter.complete(result);
    _eventQueue._addToStream(result);
  }

  @pragma('vm:prefer-inline')
  void _completedError(Object error, stackTrace) {
    if (_completed) return;

    _completed = true;
    _outCompleter.completeError(error, stackTrace);
    _eventQueue._addErrorToStream(error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void _innerComplete() {
    if (_innerCompleter != null) {
      assert(!_innerCompleter!.isCompleted);
      _innerCompleter!.complete();
      _innerCompleter = null;
    }
  }

  void _completeAll(T result) {
    if (_innerCompleter != null) {
      _innerComplete();
      _complete(result);
    }
  }

  void _completeErrorAll(Object error, stackTrace) {
    if (_innerCompleter != null) {
      _innerComplete();
      _completedError(error, stackTrace);
    }
  }
}

class _TaskKeys extends Equatable {
  _TaskKeys(dynamic key, int channels) : props = [channels, key];

  @override
  final List<Object?> props;
}

enum _ChannelState {
  /// 任务数量无限制
  run,

  /// 数量限制
  limited,

  /// 单任务
  one,
}

class _TaskIgnore {
  _TaskIgnore(this.ignore);

  bool ignore;
}

@Deprecated('use idleWait')
Future<void> get releaseUI => idleWait;

/// 进入 事件循环 等待事件调度
/// flutter engine 根据任务类型是否立即执行事件回调
/// 后续的任务会在恰当的时机运行，比如帧渲染优先等
Future<void> get idleWait => release(Duration.zero);
Future<void> release(Duration time) => Future.delayed(time);

extension EventsPush<T> on FutureOr<T> Function() {
  void push(EventQueue events, {Object? taskKey}) {
    return events.addEventTask(this, taskKey: taskKey);
  }

  void pushOne(EventQueue events, {Object? taskKey}) {
    return events.addOneEventTask(this, taskKey: taskKey);
  }

  Future<T> pushAwait(EventQueue events, {Object? taskKey}) {
    return events.awaitTask(this, taskKey: taskKey);
  }

  Future<T?> pushOneAwait(EventQueue events, {Object? taskKey}) {
    return events.awaitOne(this, taskKey: taskKey);
  }
}
