import 'package:equatable/equatable.dart';

class ListKey extends Equatable {
  ListKey(Object key) : props = [key];

  @override
  final List<Object?> props;
}
