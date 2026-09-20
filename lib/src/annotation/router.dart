class Param {
  const Param({this.name = '', this.fromJson}) : isQuery = false;
  const Param.query({this.name = '', this.fromJson}) : isQuery = true;
  final String name;
  final Function? fromJson;
  final bool isQuery;
}

class RouterMain with RouterBase {
  const RouterMain({
    this.name = '',
    this.className = '',
    this.restorationId,
    this.navClassName = '',
    this.classToNameReg = '',
    required this.page,
    this.pages = const [],
    this.pageBuilder,
    this.genKey = false,
    this.private = true,
    this.redirectFn,
    this.errorBuilder,
  }) : groupList = const [];

  final String className;
  final String navClassName;
  final bool genKey;
  final bool private;
  @override
  final String classToNameReg;

  final String? restorationId;

  @override
  final Function? redirectFn;

  @override
  final String name;
  @override
  final dynamic page;
  @override
  final List<RouterPage> pages;
  @override
  final PageBuildFn? pageBuilder;

  /// 不会从 parent Route 寻找
  @override
  final List<Type> groupList;

  ///```dart
  /// RouteQueueEntry Function(String location, Map params, Map extra, Object? groupId);
  /// ```
  final Function? errorBuilder;
}

class RouterPage with RouterBase {
  const RouterPage({
    this.name = '',
    this.classToNameReg,
    required this.page,
    this.pages = const [],
    this.pageBuilder,
    this.groupList = const [],
    this.redirectFn,
  });

  @override
  final String? classToNameReg;

  @override
  final String name;
  @override
  final dynamic page;
  @override
  final List<RouterPage> pages;
  @override
  final PageBuildFn? pageBuilder;

  @override
  final Function? redirectFn;

  /// 不会从 parent Route 寻找
  @override
  final List<Type> groupList;
}

/// {@template nop_annotations.annotation.PageBuildFn}
/// ```dart
///  Page Function(RouteQueueEntry entry, Widget child);
/// ```
/// {@endtemplate}
typedef PageBuildFn = Function;

mixin RouterBase {
  String get name;
  String? get classToNameReg;

  dynamic get page;
  List<RouterPage> get pages;

  /// {@macro nop_annotations.annotation.PageBuildFn}
  PageBuildFn? get pageBuilder;

  ///```dart
  /// RouteQueueEntry Function(RouteQueueEntry entry);
  /// ```
  Function? get redirectFn;

  /// 不会从 parent Route 寻找
  List<Type> get groupList;
}

/// 类型: Widget Function(BuildContext context,Widget child)
class RouteBuilderItem {
  const RouteBuilderItem({this.pages = const []});
  // element: class or function
  final List<dynamic> pages;
}
