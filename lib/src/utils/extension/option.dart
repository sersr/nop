import 'dart:async';

import '../match/option.dart';
import '../../../event_queue.dart';

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
