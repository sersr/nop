import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../event_queue.dart';

class OneOverrides extends IOOverrides {
  static final _fileKey = Object();
  final int channels;
  @override
  File createFile(String path) {
    return OneFile(super.createFile(path));
  }

  OneOverrides({this.channels = 1});

  Future<R> runTask<R>(Future<R> Function() task) {
    return EventQueue.run(_fileKey, task, channels: channels);
  }
}

/// 避免IO密集
class OneFile extends FileDelegate {
  OneFile(File delegate) : super(delegate);

  static R runZoned<R>(R Function() body, {int channels = 1}) {
    return IOOverrides.runWithIOOverrides(
        body, OneOverrides(channels: channels));
  }

  static Future<R> runTask<R>(Future<R> Function() task) {
    final overrides = IOOverrides.current;
    if (overrides is OneOverrides) {
      return overrides.runTask(task);
    }
    return task();
  }

  @override
  Future<Uint8List> readAsBytes() {
    return runTask(super.readAsBytes);
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    return runTask(() => super.readAsString(encoding: encoding));
  }

  @override
  Future<File> writeAsBytes(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {
    return runTask(() => super.writeAsBytes(bytes, mode: mode, flush: flush));
  }

  @override
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    return runTask(
        () => super.writeAsString(contents, mode: mode, flush: flush));
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    return super.open(mode: mode).then(OneRandomAccessFile.wrap);
  }
}

class OneRandomAccessFile extends RandomAccessFileDelegate {
  OneRandomAccessFile.wrap(RandomAccessFile delegate) : super(delegate);
  static Future<R> runTask<R>(Future<R> Function() task) {
    return OneFile.runTask(task);
  }

  @override
  Future<Uint8List> read(int count) {
    return runTask(() => super.read(count));
  }

  @override
  Future<int> readByte() {
    return runTask(super.readByte);
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) {
    return runTask(() => super.readInto(buffer, start, end));
  }

  @override
  Future<RandomAccessFile> writeByte(int value) {
    return runTask(() => super.writeByte(value));
  }

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer,
      [int start = 0, int? end]) {
    return runTask(() => super.writeFrom(buffer, start, end));
  }

  @override
  Future<RandomAccessFile> writeString(String string,
      {Encoding encoding = utf8}) {
    return runTask(() => super.writeString(string, encoding: encoding));
  }
}

class RandomAccessFileDelegate extends RandomAccessFile {
  RandomAccessFileDelegate(this.delegate);
  final RandomAccessFile delegate;

  @override
  Future<void> close() {
    return delegate.close();
  }

  @override
  void closeSync() {
    return delegate.closeSync();
  }

  @override
  Future<RandomAccessFile> flush() {
    return delegate.flush();
  }

  @override
  void flushSync() {
    return delegate.flushSync();
  }

  @override
  Future<int> length() {
    return delegate.length();
  }

  @override
  int lengthSync() {
    return delegate.lengthSync();
  }

  @override
  Future<RandomAccessFile> lock(
      [FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) {
    return delegate.lock(mode, start, end);
  }

  @override
  void lockSync(
      [FileLock mode = FileLock.exclusive, int start = 0, int end = -1]) {
    return delegate.lockSync(mode, start, end);
  }

  @override
  String get path => delegate.path;

  @override
  Future<int> position() {
    return delegate.position();
  }

  @override
  int positionSync() {
    return delegate.positionSync();
  }

  @override
  Future<Uint8List> read(int count) {
    return delegate.read(count);
  }

  @override
  Future<int> readByte() {
    return delegate.readByte();
  }

  @override
  int readByteSync() {
    return delegate.readByteSync();
  }

  @override
  Future<int> readInto(List<int> buffer, [int start = 0, int? end]) {
    return delegate.readInto(buffer, start, end);
  }

  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    return delegate.readIntoSync(buffer, start, end);
  }

  @override
  Uint8List readSync(int count) {
    return delegate.readSync(count);
  }

  @override
  Future<RandomAccessFile> setPosition(int position) {
    return delegate.setPosition(position);
  }

  @override
  void setPositionSync(int position) {
    return delegate.setPositionSync(position);
  }

  @override
  Future<RandomAccessFile> truncate(int length) {
    return delegate.truncate(length);
  }

  @override
  void truncateSync(int length) {
    return delegate.truncateSync(length);
  }

  @override
  Future<RandomAccessFile> unlock([int start = 0, int end = -1]) {
    return delegate.unlock(start, end);
  }

  @override
  void unlockSync([int start = 0, int end = -1]) {
    return delegate.unlockSync(start, end);
  }

  @override
  Future<RandomAccessFile> writeByte(int value) {
    return delegate.writeByte(value);
  }

  @override
  int writeByteSync(int value) {
    return delegate.writeByteSync(value);
  }

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer,
      [int start = 0, int? end]) {
    return delegate.writeFrom(buffer, start, end);
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    return delegate.writeFromSync(buffer, start, end);
  }

  @override
  Future<RandomAccessFile> writeString(String string,
      {Encoding encoding = utf8}) {
    return delegate.writeString(string, encoding: encoding);
  }

  @override
  void writeStringSync(String string, {Encoding encoding = utf8}) {
    return delegate.writeStringSync(string, encoding: encoding);
  }
}

class FileDelegate implements File {
  FileDelegate(this.delegate);
  final File delegate;

  @override
  File get absolute => delegate.absolute;

  @override
  Future<File> copy(String newPath) {
    return delegate.copy(newPath);
  }

  @override
  File copySync(String newPath) {
    return delegate.copySync(newPath);
  }

  @override
  Future<File> create({bool recursive = false}) {
    return delegate.create(recursive: recursive);
  }

  @override
  void createSync({bool recursive = false}) {
    return delegate.createSync(recursive: recursive);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    return delegate.delete(recursive: recursive);
  }

  @override
  void deleteSync({bool recursive = false}) {
    return delegate.deleteSync(recursive: recursive);
  }

  @override
  Future<bool> exists() {
    return delegate.exists();
  }

  @override
  bool existsSync() {
    return delegate.existsSync();
  }

  @override
  bool get isAbsolute => delegate.isAbsolute;

  @override
  Future<DateTime> lastAccessed() {
    return delegate.lastAccessed();
  }

  @override
  DateTime lastAccessedSync() {
    return delegate.lastAccessedSync();
  }

  @override
  Future<DateTime> lastModified() {
    return delegate.lastModified();
  }

  @override
  DateTime lastModifiedSync() {
    return delegate.lastAccessedSync();
  }

  @override
  Future<int> length() {
    return delegate.length();
  }

  @override
  int lengthSync() {
    return delegate.lengthSync();
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    return delegate.open(mode: mode);
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    return delegate.openRead(start, end);
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    return delegate.openSync(mode: mode);
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    return delegate.openWrite(mode: mode, encoding: encoding);
  }

  @override
  Directory get parent => delegate.parent;

  @override
  String get path => delegate.path;

  @override
  Future<Uint8List> readAsBytes() {
    return delegate.readAsBytes();
  }

  @override
  Uint8List readAsBytesSync() {
    return delegate.readAsBytesSync();
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) {
    return delegate.readAsLines(encoding: encoding);
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    return delegate.readAsLinesSync(encoding: encoding);
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    return delegate.readAsString(encoding: encoding);
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return delegate.readAsStringSync(encoding: encoding);
  }

  @override
  Future<File> rename(String newPath) {
    return delegate.rename(newPath);
  }

  @override
  File renameSync(String newPath) {
    return delegate.renameSync(newPath);
  }

  @override
  Future<String> resolveSymbolicLinks() {
    return delegate.resolveSymbolicLinks();
  }

  @override
  String resolveSymbolicLinksSync() {
    return delegate.resolveSymbolicLinksSync();
  }

  @override
  Future setLastAccessed(DateTime time) {
    return setLastAccessed(time);
  }

  @override
  void setLastAccessedSync(DateTime time) {
    return delegate.setLastAccessedSync(time);
  }

  @override
  Future setLastModified(DateTime time) {
    return delegate.setLastModified(time);
  }

  @override
  void setLastModifiedSync(DateTime time) {
    return delegate.setLastModifiedSync(time);
  }

  @override
  Future<FileStat> stat() {
    return delegate.stat();
  }

  @override
  FileStat statSync() {
    return delegate.statSync();
  }

  @override
  Uri get uri => delegate.uri;

  @override
  Stream<FileSystemEvent> watch(
      {int events = FileSystemEvent.all, bool recursive = false}) {
    return delegate.watch(events: events, recursive: false);
  }

  @override
  Future<File> writeAsBytes(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {
    return delegate.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  void writeAsBytesSync(List<int> bytes,
      {FileMode mode = FileMode.write, bool flush = false}) {
    return delegate.writeAsBytesSync(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> writeAsString(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    return delegate.writeAsString(contents,
        mode: mode, encoding: encoding, flush: flush);
  }

  @override
  void writeAsStringSync(String contents,
      {FileMode mode = FileMode.write,
      Encoding encoding = utf8,
      bool flush = false}) {
    return delegate.writeAsStringSync(contents,
        mode: mode, encoding: encoding, flush: flush);
  }
}
