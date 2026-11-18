import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

extension RawSocketExtensions on RawSocket {
  /// Reads exactly [length] bytes, waiting [readWaitDuration] (or a single
  /// turn of the event loop) between two attempts while some are missing.
  Task<ByteData> readSync({
    required final int length,
    final Option<Duration> readWaitDuration = const None<Duration>(),
  }) =>
      Task<ByteData>(
        () async {
          final BytesBuilder bytesBuilder = BytesBuilder();
          while (bytesBuilder.length < length) {
            optionOf(
              read(
                min(length, length - bytesBuilder.length),
              ),
            ).match(
              () {},
              bytesBuilder.add,
            );
            if (bytesBuilder.length < length) {
              // Always through a timer, even without [readWaitDuration]: a
              // bare `await` only runs microtasks, so the isolate would never
              // handle its other events (e.g. the pointer events to send)
              // while data is missing.
              await Future<void>.delayed(
                readWaitDuration.getOrElse(() => Duration.zero),
              );
            }
          }
          return ByteData.sublistView(bytesBuilder.toBytes());
        },
      );
}
