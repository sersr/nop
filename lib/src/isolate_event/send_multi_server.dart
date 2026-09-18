import 'dart:async';

import 'package:nop/nop.dart';

class IsolateManager {
  final _isloateRunners = <IsolateRunner>[];

  Future<void> start() {
    return _isloateRunners.map((e) => e.init()).wait;
  }

  void addRunner(IsolateRunner runner) {
    if (runner.messager.manager != null) return;
    if (_isloateRunners.contains(runner)) return;
    _isloateRunners.add(runner);
    runner.messager.updateManager(this);
  }

  void removeRunner(IsolateRunner runner) {
    if (runner.messager.manager != this) return;
    runner.messager.updateManager(null);
    _isloateRunners.remove(runner);
  }

  SendHandleName? search(Type protocol) {
    for (var runner in _isloateRunners) {
      if (runner.messager.getRemoteSender(protocol, isManager: true)
          case var handle?) {
        return SendHandleName(handle, protocols: [protocol]);
      }
    }
    return null;
  }

  void dispose() {
    for (var item in _isloateRunners) {
      item.dispose();
    }

    _isloateRunners.clear();
  }
}

abstract class MessageItem {
  Type get protocol;
  Messager? _messager;

  Messager get messager => _messager!;

  bool get isValid => _messager != null;
}

class IsolateRunner<T extends MessageItem> {
  IsolateRunner({required this.remoteServer, required this.messageItem}) {
    assert(messageItem._messager == null);
    messageItem._messager = messager;
  }

  final RemoteServer remoteServer;
  final MessageConnector messager = MessageConnector();
  final T messageItem;

  bool get initiated => remoteServer.lastSendHandle != null;

  Future<void> init() async {
    return remoteServer
        .create(messager.localSendHandle)
        .then(messager.connectTo);
  }

  Future<bool> closeServer() async {
    final currentSendHandleName = remoteServer.lastSendHandle;
    if (currentSendHandleName == null) return false;

    for (var item in currentSendHandleName.protocols) {
      if (messager.contains(item)) {
        final res = await messager.sendMessage(
          KeyType.closeServer,
          null,
          protocol: item,
        );

        if (res == true) {
          remoteServer.kill();
          return true;
        }
      }
    }

    return false;
  }

  void dispose() {
    closeServer().whenComplete(messager.dispose);
  }
}

class IsolateResolve
    with Resolve, SendEventMixin, SendCacheMixin, ConnectorMixin {
  @override
  bool listen(message) {
    if (super.listen(message)) return true;
    if (add(message)) return true;
    return false;
  }

  @override
  FutureOr<void> onInitStart() {
    assert(remoteSendHandle != null);
    connectTo(SendHandleName(remoteSendHandle!, protocols: [KeyType]));
    return super.onInitStart();
  }

  Future<bool> connectToMessager(MessageItem messageItem) async {
    messageItem._messager = this;
    await remoteSendHandleAsync;
    final sendHandle = await sendMessage<SendHandleName>(
      KeyType.connectToProtocol,
      messageItem.protocol,
      protocol: KeyType,
    );
    connectTo(sendHandle);
    onResume();
    return true;
  }

  @override
  bool remove(key) {
    if (super.remove(key)) return true;

    if (key case SendMessage(type: KeyType.closeServer)) {
      onClose().whenComplete(() => key.receipt(true));
      return true;
    }

    return false;
  }
}

mixin ConnectorMixin on SendEvent, Messager {
  final _remoteSendHandles = <Type, SendHandle>{};

  bool contains(Type protocol) {
    return _remoteSendHandles.containsKey(protocol);
  }

  void connectTo(SendHandleName remoteServer) {
    for (var protocol in remoteServer.protocols) {
      _remoteSendHandles[protocol] = remoteServer.sendHandle;
      Log.i('protocol: $protocol connected.');
      onResume();
    }
  }

  @override
  SendHandle? getRemoteSender(Type? protocol) {
    final remoteHandle = _remoteSendHandles[protocol];
    if (remoteHandle != null) {
      return remoteHandle;
    }

    return super.getRemoteSender(protocol);
  }
}

final class MessageConnector
    with
        SendEventMixin,
        SendEventPortStreamMixin,
        SendCacheMixin,
        ConnectorMixin {
  MessageConnector() {
    _rcHandle.listen(onListen);
  }
  IsolateManager? _isolateManager;

  IsolateManager? get manager => _isolateManager;

  final _rcHandle = ReceiveHandle();

  void updateManager(IsolateManager? manager) {
    _isolateManager = manager;
  }

  @override
  SendHandle get localSendHandle => _rcHandle.sendHandle;

  void onListen(dynamic message) {
    if (add(message)) return;
    if (message case SendMessage(type: KeyType.connectToProtocol)) {
      try {
        final handle = _isolateManager?.search(message.args);
        message.receipt(handle);
      } catch (e) {
        message.receipt(e, result: .failed);
      }
    }
  }

  @override
  SendHandle? getRemoteSender(Type? protocol, {bool isManager = false}) {
    final current = super.getRemoteSender(protocol);
    if (current != null) return current;
    if (protocol == null) return null;
    if (isManager) return null;

    final other = _isolateManager?.search(protocol);
    if (other != null) {
      connectTo(other);
    }
    return other?.sendHandle;
  }

  void close() {
    _rcHandle.close();
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}
