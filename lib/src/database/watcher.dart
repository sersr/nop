import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../event_queue.dart';
import '../event_dispatch/event_dispatch.dart';
import 'map_list.dart';
import 'table.dart';

class QueryStreamKey extends Equatable {
  QueryStreamKey(this.tables, this.updateItems, this.sql);
  final Set<DatabaseTable> tables;
  final Set<String> updateItems;
  final String sql;

  @override
  List<Object?> get props => [tables, updateItems, sql];

  late final _tablesAll = tables.map((e) => '${e.table}.*');

  bool onMatch(NotifyKey notifier) {
    if (!matchListItem(tables, notifier.tables)) return false;
    if (notifier is DeleteNotifyKey) return true;
    if (notifier is InsertNotifyKey) {}

    return updateItems.isEmpty ||
        _tablesAll.any((e) => updateItems.contains(e)) ||
        matchListItem(updateItems, notifier.updateItems);
  }
}

class NotifyKey {
  NotifyKey(this.tables, this.updateItems);
  final Set<String> updateItems;
  final Set<DatabaseTable> tables;
}

class DeleteNotifyKey extends NotifyKey {
  DeleteNotifyKey(Set<DatabaseTable> table) : super(table, const {});
}

class UpdateNotifyKey extends NotifyKey {
  UpdateNotifyKey(Set<DatabaseTable> table, Set<String> updateItems)
      : super(table, updateItems);
}

class InsertNotifyKey extends NotifyKey {
  InsertNotifyKey(Set<DatabaseTable> table, Set<String> updateItems)
      : super(table, updateItems);
}

typedef QueryListener = FutureOr<List<Map<String, Object?>>> Function();

class _Listener with StreamLazyMixin<List<Map<String, Object?>>> {
  _Listener(this.listener, this.watcher, this.go);

  final QueryStreamKey listener;
  final Watcher watcher;
  final QueryListener go;

  bool _removed = false;
  @override
  void dispose() {
    _removed = true;
    watcher.remove(listener);
  }

  void _run() {
    scheduled = false;
    EventQueue.pushOne(this, () {
      if (!_removed) {
        return go().then((newData) {
          if (_removed) return;
          if (equality.equals(newData, lastData)) return;
          add(newData);
        });
      }
    });
  }

  bool scheduled = false;

  @override
  void notifyClient() {
    if (isPaused || scheduled) return;
    scheduleMicrotask(_run);
    scheduled = true;
  }

  @override
  bool get shouldCache => false;
}

class Watcher {
  Watcher();

  final listeners = <QueryStreamKey, _Listener>{};
  _Listener add(QueryStreamKey listener, QueryListener callback) {
    return listeners.putIfAbsent(
        listener, () => _Listener(listener, this, callback));
  }

  void remove(QueryStreamKey listerner) {
    listeners.remove(listerner);
  }

  void notifyListener(NotifyKey notifier) {
    listeners.values
        .where((l) => !l.isPaused && l.listener.onMatch(notifier))
        // .where((e) => !e.isPaused)
        .forEach(_innerForEach);
  }

  void _innerForEach(_Listener listener) {
    listener.notifyClient();
  }
}
