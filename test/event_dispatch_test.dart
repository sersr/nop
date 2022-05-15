// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nop/event_queue.dart';
import 'package:nop/event_dispatch.dart';
// ignore: unnecessary_import

import 'run_zone.dart';

void main() async {
  final lcontroller = ListenerController<String>();
  test('event test', () async {
    await runZone(() async {
      final stream = lcontroller.stream;
      expect(lcontroller.hasListener, false);
      expect(lcontroller.listenUnits.length, 0);
      lcontroller.stream;
      expect(lcontroller.hasListener, false);
      expect(lcontroller.listenUnits.length, 0);
      final stream3 = lcontroller.stream;
      expect(lcontroller.hasListener, false);

      final listen3 = stream3.listen((event) => print('sss'),
          onDone: () => print('stream3 done'));
      expect(lcontroller.hasListener, true);
      expect(lcontroller.listenUnits.length, 1);
      listen3.pause();
      lcontroller.add('sfsfs');

      expect(lcontroller.listenUnits.length, 1);
      listen3.resume();
      expect(lcontroller.listenUnits.length, 1);

      lcontroller.cancel();

      expect(lcontroller.listenUnits.length, 0);

      lcontroller.add('new value');
      stream.listen((event) => print('listen 1 $event'),
          onDone: () => print('done'));
      // 主控制器已关闭，只会接受一次数据然后立即关闭流
      // `add`会更新缓存中的数据
      expect(lcontroller.listenUnits.length, 0);
      expect(lcontroller.hasListener, false);
    });
  });
  test('description', () async {
    final s = StreamController(onCancel: () => print('ons..'));
    final sub = s.stream.listen((event) {
      print('evn');
    });
    sub.pause();
    s.done.then((value) => print('done'));
    await sub.cancel();
    s.add('aaa');
    await runZone(() async {
      final ss = StreamController(onCancel: () => print('ons..'));
      ss.stream.listen((event) {
        print('evn');
      }, onDone: () {
        print('done');
      });
      // 没有订阅者，不会完成
      await ss.close();
      print('done...');
    });
  });

  test('stream', () async {
    late StreamController controller;
    controller = StreamController(onListen: () {
      print('listen');
    }, onPause: () {
      print('pause');
    }, onCancel: () {
      print('cancel...');
      controller.close().then((v) {
        print('....');
      });
    });
    final sub = controller.stream.listen((event) {
      print('event: $event');
    });
    print(sub.isPaused);
    sub.pause();
    print(sub.isPaused);
    controller.add('hello');
    controller.add('world');
    controller.add('world');
    controller.add('world');
    controller.add('world');
    controller.close();
    await release(const Duration(seconds: 2));
    sub.resume();
    // sub.cancel();
  });
  test('listen Controller', () async {
    final controller = ListenerController<String>();
    controller.add('hello');
    controller.cancel();
    // 自动关闭`stream`
    controller.stream.listen((event) {
      print('event: $event');
    }, onDone: () {
      print('done...');
    });
    print('..main');
  });
  test('queue', () async {
    await runZone(() async {
      final lcontroller = StreamLazyController<String>();
      final stream = lcontroller.stream;
      expect(lcontroller.hasListener, false);
      expect(lcontroller.activeUnits.length, 0);
      lcontroller.stream;
      expect(lcontroller.hasListener, false);
      expect(lcontroller.activeUnits.length, 0);
      final stream3 = lcontroller.streamAsync;
      expect(lcontroller.hasListener, false);

      final listen3 = stream3.listen((event) => print('sss'),
          onDone: () => print('stream3 done'));
      expect(lcontroller.hasListener, true);
      expect(lcontroller.activeUnits.length, 1);
      listen3.pause();
      lcontroller.add('sfsfs');

      expect(lcontroller.activeUnits.length, 0);

      listen3.resume();
      expect(lcontroller.activeUnits.length, 1);

      lcontroller.cancel();

      expect(lcontroller.activeUnits.length, 0);

      lcontroller.add('new value');
      stream.listen((event) => print('listen 1 $event'),
          onDone: () => print('done'));
      // 主控制器已关闭，只会接受一次数据然后立即关闭流
      // `add`会更新缓存中的数据
      expect(lcontroller.activeUnits.length, 0);
      expect(lcontroller.hasListener, false);
      await release(const Duration(milliseconds: 500));
    });
  });
}
