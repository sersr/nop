import 'dart:async';

import 'package:meta/meta.dart';

import '../../event_queue.dart';
import '../../utils.dart';
import 'event.dart';
import 'message.dart';
import 'remote_server.dart';
import 'send_init_close_mixin.dart';

typedef AddTask = void Function(FutureOr task);

/// 管理多个 [RemoteServer]
mixin SendMultiServerMixin on SendEvent, ListenMixin {
  var remoteServers = <String, RemoteServer>{};
  var sendHandleOwners = <String, SendHandleOwner>{};

  @mustCallSuper
  Map<String, RemoteServer> regRemoteServer() => {};

  void _createAllServer(AddTask add) {
    remoteServers = regRemoteServer();
    for (var remoteServer in remoteServers.values) {
      final task = remoteServer.create();
      add(task);
    }
  }

  Map<String, Set<Type>>? _privateProtocols;

  Map<String, Set<Type>> get _allProtocols {
    if (_privateProtocols != null) return _privateProtocols!;
    final map = <String, Set<Type>>{};
    for (var item in getProtocols().entries) {
      final protocols = map.putIfAbsent(item.key, () => <Type>{});
      protocols.addAll(item.value);
    }
    return _privateProtocols = map;
  }

  List<Type>? getMessagerProtocols(String serverName) {
    return _allProtocols[serverName]?.toList(growable: false);
  }

  final allServerProtocols = <String, List<Type>?>{};
  List<Type>? getServerProtocols(String serverName) {
    return allServerProtocols[serverName];
  }

  void connect(String from, String to, {List<Type>? localProt}) {
    SendHandle toSendHandle;
    List<Type>? prot;
    if (localProt != null) {
      toSendHandle = localSendHandle;
      prot = localProt;
    } else {
      toSendHandle = sendHandleOwners[to]!.localSendHandle;
      prot = getServerProtocols(to);
    }

    final sendHandleName = SendHandleName(to, toSendHandle, protocols: prot);
    sendHandleOwners[from]!.localSendHandle.send(sendHandleName);
  }

  @override
  bool onListenReceivedSendHandle(SendHandleName sendHandleName) {
    if (!sendHandleName.isToRemote) {
      final protocols = _allProtocols[sendHandleName.name];
      if (protocols != null) {
        final equal = sendHandleName.protocols != null &&
            protocols.every(sendHandleName.protocols!.contains);
        final sendHandleOwner = SendHandleOwner(
            localSendHandle: sendHandleName.sendHandle,
            remoteSendHandle: localSendHandle);
        allServerProtocols[sendHandleName.name] = sendHandleName.protocols;
        sendHandleOwners[sendHandleName.name] = sendHandleOwner;
        Log.i(
            'init: protocol status: $equal | ${sendHandleName.name} | $protocols',
            onlyDebug: false);
        return true;
      }
    }
    return super.onListenReceivedSendHandle(sendHandleName);
  }

  @override
  SendHandleOwner? getSendHandleOwner(serverName) {
    final sendHandleOwner = sendHandleOwners[serverName];
    if (sendHandleOwner != null) {
      return sendHandleOwner;
    }
    if (!_allProtocols.containsKey(serverName)) {
      Log.e('sendHandleOwner == null | remoteName: $serverName',
          onlyDebug: false);
    }
    return super.getSendHandleOwner(serverName);
  }

  void _disposeRemoteServer(String serverName) {
    assert(sendHandleOwners.containsKey(serverName));
    sendHandleOwners.remove(serverName);
  }

  /// impl [SendInitCloseMixin]
  /// NOTE: 直接调用[initTask]是不安全的
  FutureOr<void> initTask() async {
    if (_initialized) return;
    notifyState(false);
    return run();
  }

  bool get _initialized =>
      remoteServers.isNotEmpty || sendHandleOwners.isNotEmpty;

  @override
  void initStateListen(add) {
    assert(!_initialized, '应该使用`锁`调用`initTask`,`closeTask`');
    _createAllServer(add);
    super.initStateListen(add);
  }

  /// [sendHandleOwners]都已经初始化
  @override
  void onResumeListen() {
    super.onResumeListen();
    if (!_allProtocols.keys.every(sendHandleOwners.containsKey)) {
      Log.e(
          'sendHandleOwners: ${sendHandleOwners.keys} > isolatNames: ${_allProtocols.keys}',
          onlyDebug: false);
    }
    onResume();
    notifyState(true);
  }

  @override
  FutureOr<void> onListen(ReceiveHandle receiveHandle) async {
    Completer<void>? completer;

    final allServerNames = List.of(remoteServers.keys);
    if (allServerNames.isNotEmpty) completer = Completer<void>();

    receiveHandle.listen((message) {
      if (add(message)) return;
      if (listen(message) || message is SendHandleName) {
        if (message is SendHandleName && !message.isToRemote) {
          final removed = allServerNames.remove(message.name);
          assert(removed || Log.i('can not remove: ${message.name} server'));
          if (allServerNames.isEmpty) {
            if (completer != null) {
              completer!.complete();
              completer = null;
            }
          }
        }
        return;
      }
      if (message == _closeKey) {
        Log.e('close root receiveHandle: done', onlyDebug: false);
        receiveHandle.close();
        return;
      }
      assert(Log.e('error message: $message'));
    });

    return completer?.future;
  }

  @visibleForTesting
  Future<void> closeRemoteServer(String serverName) async {
    if (remoteServers.isEmpty) return;
    return EventQueue.runOne(this, () async {
      if (!remoteServers.containsKey(serverName)) return;
      final rcHandle = ReceiveHandle();
      _closeRemoteServer(rcHandle.sendHandle, serverName);
      // final timer = Timer(
      //     const Duration(milliseconds: 10000),
      //     () => Log.w('如果一直卡在这里，有可能是远程`throw`没有被捕获，建议使用`runZonedGuarded`',
      //         onlyDebug: false));
      final result = await rcHandle.first;
      Log.i('close: $result', onlyDebug: false);
      // timer.cancel();
    });
  }

  void _closeRemoteServer(SendHandle sendHandle, String serverName) {
    final oldServer = remoteServers[serverName];

    if (oldServer != null) {
      if (oldServer.killed) {
        remoteServers.remove(serverName);
      } else {
        send(KeyController(sendHandle, KeyType.closeServer, serverName));
      }
      _disposeRemoteServer(serverName);
    }
  }

  /// impl [SendInitCloseMixin]
  /// NOTE: 直接调用[closeTask]是不安全的
  FutureOr<void> closeTask() async {
    if (remoteServers.isEmpty) return;
    dispose();
    notifyState(false);
    final rcHandle = ReceiveHandle();
    final servers = Map.of(remoteServers)..removeWhere((e, v) => v.killed);
    for (var server in servers.entries) {
      _closeRemoteServer(rcHandle.sendHandle, server.key);
    }

    if (servers.isNotEmpty) {
      final timer = Timer(const Duration(milliseconds: 10000), () {
        Log.w('timeout: 10 seconds', onlyDebug: false);
      });

      await for (var message in rcHandle) {
        if (message is SendHandleName) {
          servers.remove(message.name);
          final removedIsolate = remoteServers.remove(message.name);
          if (removedIsolate != null) {
            Log.w('close server: ${message.name}', onlyDebug: false);
            removedIsolate.kill();
          }

          if (servers.isEmpty) {
            remoteServers.clear();
            rcHandle.close();
            localSendHandle.send(_closeKey);
          }
        }
        timer.cancel();
      }
    }

    Log.w('close: success', onlyDebug: false);
  }

  static const _closeKey = 'close_root_receive_handle';
}

/// 子隔离 连接 其他隔离 的实现
/// 比如: 加入[xxxxxxMessager]
/// 从[getProtocols]中获取协议
mixin ResolveMultiRecievedMixin on SendEvent, Resolve {
  final receivedSendHandleOwners = <String, SendHandleOwner>{};
  @override
  bool onListenReceivedSendHandle(SendHandleName sendHandleName) {
    if (!sendHandleName.isToRemote) {
      return super.onListenReceivedSendHandle(sendHandleName);
    }
    final sendHandleOwner = SendHandleOwner(
      localSendHandle: sendHandleName.sendHandle,
      remoteSendHandle: localSendHandle,
    );
    final localProts = sendHandleName.protocols;
    var success = false;
    Iterable<Type> prots = const [];
    if (localProts != null) {
      prots = getProtocols()
          .entries
          .where((e) => e.key == sendHandleName.name)
          .expand((e) => e.value);
      success = prots.every(localProts.contains);
    }
    if (success) {
      Log.i('$runtimeType: received ${sendHandleName.name} | $localProts',
          onlyDebug: false);
    } else {
      Log.w('not matched, ${sendHandleName.name}, $prots, $localProts');
    }

    assert(!receivedSendHandleOwners.containsKey(sendHandleName.name),
        sendHandleName.name);
    receivedSendHandleOwners[sendHandleName.name] = sendHandleOwner;
    onResume();
    return true;
  }

  @override
  bool listen(message) {
    if (add(message)) return true;
    return super.listen(message);
  }

  @override
  SendHandleOwner? getSendHandleOwner(serverName) {
    final sendHandleOwner = receivedSendHandleOwners[serverName];
    if (sendHandleOwner != null) return sendHandleOwner;
    Log.e('remoteName: $serverName == null', onlyDebug: false);
    return super.getSendHandleOwner(serverName);
  }

  @override
  FutureOr<void> onClose() async {
    receivedSendHandleOwners.clear();
    return super.onClose();
  }
}
