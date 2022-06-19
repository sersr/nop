import 'dart:async';

import '../../../event_queue.dart';

abstract class Option<V> {
  const Option();
  S map<S>({required S Function() ifNone, required S Function(V v) ifSome});
}

class None<V> extends Option<V> {
  const None();

  @override
  S map<S>({required S Function() ifNone, required S Function(V v) ifSome}) =>
      ifNone();
}

class Some<V> extends Option<V> {
  const Some(this.v);
  const factory Some.wrap(V v) = Some;
  final V v;
  @override
  S map<S>({required S Function() ifNone, required S Function(V v) ifSome}) =>
      ifSome(v);
}



/// 将其他任何类型转化为[Option]类型
extension OptionFutureExt<T> on FutureOr<T?> {
  FutureOr<Option<T>> optionFut() {
    return then((value) {
      if (value == null) return const None();
      return Some(value);
    }, onError: (e) => const None());
  }

  FutureOr<S> mapOption<S>({
    required FutureOr<S> Function() ifNone,
    required FutureOr<S> Function(T v) ifSome,
  }) {
    return optionFut().then((value) {
      return value.map(ifNone: ifNone, ifSome: ifSome);
    });
  }
}

/// 将[Option?]转化为[Option]
extension MapOnOption<T> on FutureOr<Option<T>?> {
  FutureOr<Option<T>> optionFut() {
    return then((value) => value ?? const None(), onError: (e) => const None());
  }

  FutureOr<S> mapOption<S>({
    required FutureOr<S> Function() ifNone,
    required FutureOr<S> Function(T v) ifSome,
  }) {
    return optionFut().then((value) {
      return value.map(ifNone: ifNone, ifSome: ifSome);
    });
  }
}

extension OptionFutureOrNull<T> on FutureOr<T>? {
  FutureOr<Option<T>> andOptionFut() {
    return andThen((value) {
      if (value == null) return const None();
      return Some(value);
    }, onError: (e) => const None());
  }

  FutureOr<S> andMapOption<S>({
    required FutureOr<S> Function() ifNone,
    required FutureOr<S> Function(T v) ifSome,
  }) {
    return andOptionFut().then((value) {
      return value.map(ifNone: ifNone, ifSome: ifSome);
    });
  }
}
