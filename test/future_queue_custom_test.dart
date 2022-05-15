// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nop/nop.dart';

import 'string_pad_right.dart';

void main() {
  test('demo', () async {
    final fq = FutureQueue();
    try {
      /// 提供初始[FutureTask]
      /// 为[Future]对象提供捕获对象
      await fq.wait;
      Log.i('start wait'.p);
      fq.run(() => Log.w('run'.p));
      try {
        scheduleMicrotask(() {
          Log.e('microtask'.p);
        });
        await customFutureFunction().catchs;
      } catch (e) {
        Log.i('catch 1: $e'.p);
      }
      Log.w(' mi: ${FutureQueueMixin.currentTask}'.p);
      try {
        await customFutureFunction().catchs;
      } catch (e) {
        Log.w('catch2 $e'.p);
      }
      await customFutureFunction().catchsOnly;
    } catch (e) {
      Log.i('catch $e'.p);
    }
  });
}

Future<void> customFutureFunction() async {
  await Future.delayed(Duration.zero);
  Log.i('other.. ${FutureQueueMixin.currentTask}'.p);
  // throw 'ssx';
}
