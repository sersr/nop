import 'dart:async';

typedef _Callback<S, T> = S Function(T);
typedef _CombineCallback<S, T> = S Function(S, T);

extension FuturOrNull<T> on FutureOr<T>? {
  FutureOr<S> andThen<S>(FutureOr<S> Function(T? value) action,
      {Function? onError}) {
    final that = this;

    if (that == null) {
      return action(null);
    } else {
      return that._innerThen(action, onError: onError);
    }
  }
}

extension FutureOrFuture<T> on FutureOr<T> {
  FutureOr<S> _innerThen<S>(FutureOr<S> Function(T value) map,
      {Function? onError}) {
    final that = this;
    if (that is Future<T>) {
      return that.then(map, onError: onError);
    }
    return map(that);
  }

  FutureOr<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return _innerThen(onValue, onError: onError);
  }

  FutureOr<T> catchError(Function onError,
      {bool Function(Object error)? test}) {
    final that = this;
    if (that is Future<T>) {
      return that.catchError(onError, test: test);
    }

    return that;
  }

  FutureOr<T> whenComplete(FutureOr<void> Function() action) {
    final that = this;
    if (that is Future<T>) {
      return that.whenComplete(action);
    }
    final f = action();
    if (f is Future) {
      return f._innerThen((_) => that, onError: (e) => that);
    }
    return that;
  }

  Stream<T> asStream() {
    final that = this;
    if (that is Future<T>) {
      return that.asStream();
    }
    return Stream.value(that);
  }

  FutureOr<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    final that = this;
    if (that is Future<T>) {
      return that.timeout(timeLimit, onTimeout: onTimeout);
    }
    return that;
  }
}

extension FutureOrIterable<T> on FutureOr<Iterable<T>> {
  FutureOr<Iterator<T>> get iterator {
    return _innerThen((list) => list.iterator);
  }

  FutureOr<Iterable<S>> cast<S>() {
    return _innerThen((list) => list.cast<S>());
  }

  FutureOr<Iterable<T>> followedBy(Iterable<T> other) {
    return _innerThen((list) => list.followedBy(other));
  }

  FutureOr<Iterable<S>> map<S>(_Callback<S, T> m) {
    return _innerThen((list) => list.map(m));
  }

  FutureOr<Iterable<T>> where(bool Function(T element) test) {
    return _innerThen((list) => list.where(test));
  }

  FutureOr<Iterable<S>> whereType<S>() {
    return _innerThen((list) => list.whereType<S>());
  }

  FutureOr<Iterable<T>> expand(_Callback<Iterable<T>, T> test) {
    return _innerThen((list) => list.expand(test));
  }

  FutureOr<bool> contains(Object? element) {
    return _innerThen((list) => list.contains(element));
  }

  FutureOr<void> forEach(_Callback<void, T> test) {
    return _innerThen((list) => list.forEach(test));
  }

  FutureOr<T> reduce(_CombineCallback<T, T> combine) {
    return _innerThen((list) => list.reduce(combine));
  }

  FutureOr<S> fold<S>(S initialValue, _CombineCallback<S, T> test) {
    return _innerThen((list) => list.fold<S>(initialValue, test));
  }

  FutureOr<bool> every(_Callback<bool, T> test) {
    return _innerThen((list) => list.every(test));
  }

  FutureOr<String> join([String separator = '']) {
    return _innerThen((list) => list.join());
  }

  FutureOr<bool> any(_Callback<bool, T> test) {
    return _innerThen((list) => list.any(test));
  }

  FutureOr<List<T>> toList({bool growable = true}) {
    return _innerThen((list) => list.toList(growable: growable));
  }

  FutureOr<Set<T>> toSet() {
    return _innerThen((list) => list.toSet());
  }

  FutureOr<int> get length {
    return _innerThen((list) => list.length);
  }

  FutureOr<bool> get isEmpty {
    return _innerThen((list) => list.isEmpty);
  }

  FutureOr<bool> get isNotEmpty {
    return _innerThen((list) => list.isNotEmpty);
  }

  FutureOr<Iterable<T>> take(int count) {
    return _innerThen((list) => list.take(count));
  }

  FutureOr<Iterable<T>> takeWhile(_Callback<bool, T> take) {
    return _innerThen((list) => list.takeWhile(take));
  }

  FutureOr<Iterable<T>> skip(int count) {
    return _innerThen((list) => list.skip(count));
  }

  FutureOr<Iterable<T>> skipWhile(_Callback<bool, T> test) {
    return _innerThen((list) => list.skipWhile(test));
  }

  FutureOr<T> get first {
    return _innerThen((list) => list.first);
  }

  FutureOr<T> get last {
    return _innerThen((list) => list.last);
  }

  FutureOr<T> get single {
    return _innerThen((list) => list.single);
  }

  FutureOr<T> firstWhere(_Callback<bool, T> test, {T Function()? orElse}) {
    return _innerThen((list) => list.firstWhere(test, orElse: orElse));
  }

  FutureOr<T> lastWhere(_Callback<bool, T> test, {T Function()? orElse}) {
    return _innerThen((list) => list.lastWhere(test, orElse: orElse));
  }

  FutureOr<T> singleWhere(_Callback<bool, T> test, {T Function()? orElse}) {
    return _innerThen((list) => list.singleWhere(test, orElse: orElse));
  }

  FutureOr<T> elementAt(int index) {
    return _innerThen((list) => list.elementAt(index));
  }

  FutureOr<String> rawString() {
    return _innerThen((list) => list.toString());
  }
}

extension FutureOrMap<K, V> on FutureOr<Map<K, V>> {
  FutureOr<Map<RK, RV>> cast<RK, RV>() {
    return _innerThen((map) => map.cast<RK, RV>());
  }

  FutureOr<bool> containsValue(Object? value) {
    return _innerThen((map) => map.containsValue(value));
  }

  FutureOr<bool> containsKey(Object? key) {
    return _innerThen((map) => map.containsKey(key));
  }

  FutureOr<Iterable<K>> get keys {
    return _innerThen((map) => map.keys);
  }

  FutureOr<Iterable<V?>> get values {
    return _innerThen((map) => map.values);
  }

  FutureOr<int> get length {
    return _innerThen((map) => map.length);
  }

  FutureOr<bool> get isEmpty {
    return _innerThen((map) => map.isEmpty);
  }

  FutureOr<bool> get isNotEmpty {
    return _innerThen((map) => map.isNotEmpty);
  }

  FutureOr<Iterable<MapEntry<K, V>>> get entries {
    return _innerThen((map) => map.entries);
  }
}
