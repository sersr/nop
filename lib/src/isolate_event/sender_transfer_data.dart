import 'dart:async';

mixin TransferType<D> {
  FutureOr<void> encode();
  FutureOr<D> decode();
}
