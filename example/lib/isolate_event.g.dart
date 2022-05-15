// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isolate_event.dart';

// **************************************************************************
// Generator: ServerEventGeneratorForAnnotation
// **************************************************************************

// ignore_for_file: annotate_overrides
// ignore_for_file: curly_braces_in_flow_control_structures
enum FirstEventMessage { workStatus, getBookName }

enum SecondEventMessage { getStream, doSecondOtherWork }

enum ThirdEventMessage { doOtherWorks }

enum SecMessage { ss }

/// 主入口
abstract class MultiIsolateMessagerMain
    with
        IsolateEvent,
        ListenMixin,
        SendEventMixin,
        SendMultiServerMixin,
        Resolve,
        FirstEventMessager,
        SecondEventMessager,
        ThirdEventMessager,
        SecResolve {
  RemoteServer get isolateRemoteServer;
  RemoteServer get firstIsolateRemoteServer;
  RemoteServer get thirdIsolateRemoteServer;
  Map<String, RemoteServer> regRemoteServer() {
    return super.regRemoteServer()
      ..['isolate'] = isolateRemoteServer
      ..['firstIsolate'] = firstIsolateRemoteServer
      ..['thirdIsolate'] = thirdIsolateRemoteServer;
  }

  void onResumeListen() {
    final localProts = getResolveProtocols();

    connect('isolate', 'firstIsolate');
    connect('thirdIsolate', 'firstIsolate');
    connect('thirdIsolate', 'sec', localProt: localProts['sec']);
    super.onResumeListen();
  }
}

/// isolate Server
abstract class MultiIsolateResolveMain
    with
        ListenMixin,
        Resolve,
        SendEventMixin,
        SendCacheMixin,
        ResolveMultiRecievedMixin,
        FirstEventMessager,
        SecondEventResolve {
  MultiIsolateResolveMain({required ServerConfigurations configurations})
      : remoteSendHandle = configurations.sendHandle;
  final SendHandle remoteSendHandle;
}

/// firstIsolate Server
abstract class MultiFirstIsolateResolveMain
    with ListenMixin, Resolve, FirstEventResolve {
  MultiFirstIsolateResolveMain({required ServerConfigurations configurations})
      : remoteSendHandle = configurations.sendHandle;
  final SendHandle remoteSendHandle;
}

/// thirdIsolate Server
abstract class MultiThirdIsolateResolveMain
    with
        ListenMixin,
        Resolve,
        SendEventMixin,
        SendCacheMixin,
        ResolveMultiRecievedMixin,
        FirstEventMessager,
        SecMessager,
        ThirdEventResolve {
  MultiThirdIsolateResolveMain({required ServerConfigurations configurations})
      : remoteSendHandle = configurations.sendHandle;
  final SendHandle remoteSendHandle;
}

/// sec Server
abstract class MultiSecResolveMain with ListenMixin, Resolve, SecResolve {
  MultiSecResolveMain({required ServerConfigurations configurations})
      : remoteSendHandle = configurations.sendHandle;
  final SendHandle remoteSendHandle;
}

mixin FirstEventResolve on Resolve implements FirstEvent {
  Map<String, List<Type>> getResolveProtocols() {
    return super.getResolveProtocols()
      ..putIfAbsent('firstIsolate', () => []).add(FirstEventMessage);
  }

  Map<Type, List<Function>> resolveFunctionIterable() {
    return super.resolveFunctionIterable()
      ..[FirstEventMessage] = [(args) => workStatus(), getBookName];
  }
}

/// implements [FirstEvent]
mixin FirstEventMessager on SendEvent, Messager {
  String get firstIsolate => 'firstIsolate';
  Map<String, List<Type>> getProtocols() {
    return super.getProtocols()
      ..putIfAbsent(firstIsolate, () => []).add(FirstEventMessage);
  }

  FutureOr<bool?> workStatus() {
    return sendMessage(FirstEventMessage.workStatus, null,
        serverName: firstIsolate);
  }

  FutureOr<String?> getBookName(int id) {
    return sendMessage(FirstEventMessage.getBookName, id,
        serverName: firstIsolate);
  }
}
mixin SecondEventResolve on Resolve implements SecondEvent, SecondOtherEvent {
  Map<String, List<Type>> getResolveProtocols() {
    return super.getResolveProtocols()
      ..putIfAbsent('isolate', () => []).add(SecondEventMessage);
  }

  Map<Type, List<Function>> resolveFunctionIterable() {
    return super.resolveFunctionIterable()
      ..[SecondEventMessage] = [
        (args) => getStream(),
        (args) => doSecondOtherWork()
      ];
  }
}

/// implements [SecondEvent]
mixin SecondEventMessager on SendEvent, Messager {
  String get isolate => 'isolate';
  Map<String, List<Type>> getProtocols() {
    return super.getProtocols()
      ..putIfAbsent(isolate, () => []).add(SecondEventMessage);
  }

  Stream<String?> getStream() {
    return sendMessageStream(SecondEventMessage.getStream, null,
        serverName: isolate);
  }

  FutureOr<void> doSecondOtherWork() {
    return sendMessage(SecondEventMessage.doSecondOtherWork, null,
        serverName: isolate);
  }
}
mixin ThirdEventResolve on Resolve implements ThirdEvent, OtherEvents {
  Map<String, List<Type>> getResolveProtocols() {
    return super.getResolveProtocols()
      ..putIfAbsent('thirdIsolate', () => []).add(ThirdEventMessage);
  }

  Map<Type, List<Function>> resolveFunctionIterable() {
    return super.resolveFunctionIterable()
      ..[ThirdEventMessage] = [(args) => doOtherWorks()];
  }
}

/// implements [ThirdEvent]
mixin ThirdEventMessager on SendEvent, Messager {
  String get thirdIsolate => 'thirdIsolate';
  Map<String, List<Type>> getProtocols() {
    return super.getProtocols()
      ..putIfAbsent(thirdIsolate, () => []).add(ThirdEventMessage);
  }

  FutureOr<void> doOtherWorks() {
    return sendMessage(ThirdEventMessage.doOtherWorks, null,
        serverName: thirdIsolate);
  }
}
mixin SecResolve on Resolve implements Sec {
  Map<String, List<Type>> getResolveProtocols() {
    return super.getResolveProtocols()
      ..putIfAbsent('sec', () => []).add(SecMessage);
  }

  Map<Type, List<Function>> resolveFunctionIterable() {
    return super.resolveFunctionIterable()..[SecMessage] = [(args) => ss()];
  }
}

/// implements [Sec]
mixin SecMessager on SendEvent, Messager {
  String get sec => 'sec';
  Map<String, List<Type>> getProtocols() {
    return super.getProtocols()..putIfAbsent(sec, () => []).add(SecMessage);
  }

  FutureOr<bool?> ss() {
    return sendMessage(SecMessage.ss, null, serverName: sec);
  }
}
