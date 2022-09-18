import 'dart:async';

class FutureAny {
  final _tasks = <Future>[];

  int get length => _tasks.length;

  bool get isEmpty => _tasks.isEmpty;
  bool get isNotEmpty => _tasks.isNotEmpty;

  Completer<void>? _completer;
  Completer<void>? _completerWaitAll;

  Future<void>? get any {
    _set();
    return _completer?.future;
  }

  Future<void>? get wait {
    _setWaitAll();
    return _completerWaitAll?.future;
  }

  void _set() {
    assert(_completer == null || !_completer!.isCompleted);

    if (_completer == null || _completer!.isCompleted) {
      if (isNotEmpty) _completer = Completer<void>();
    }
  }

  void _setWaitAll() {
    assert(_completerWaitAll == null || !_completerWaitAll!.isCompleted);

    if (_completerWaitAll == null || _completerWaitAll!.isCompleted) {
      if (isNotEmpty) _completerWaitAll = Completer<void>();
    }
  }

  void _completed() {
    /// any
    if (_completer != null) {
      assert(!_completer!.isCompleted);
      _completer!.complete();
      _completer = null;
    }

    /// waitAll
    if (isEmpty && _completerWaitAll != null) {
      assert(!_completerWaitAll!.isCompleted);
      _completerWaitAll!.complete();
      _completerWaitAll = null;
    }
  }

  void add(FutureOr task) {
    if (task is Future) {
      _tasks.add(task
        ..whenComplete(() {
          _tasks.remove(task);
          _completed();
        }));
    }
  }

  void addAll(Iterable<Future> tasks) {
    for (final task in tasks) {
      add(task);
    }
  }
}
