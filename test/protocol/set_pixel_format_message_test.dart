import 'dart:typed_data';

import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:dart_rfb/src/protocol/set_pixel_format_message.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('Set pixel format message to bytes works', () {
    const RemoteFrameBufferPixelFormat pixelFormat =
        RemoteFrameBufferPixelFormat.bgra8888;
    expect(
      const RemoteFrameBufferSetPixelFormatMessage(
        pixelFormat: pixelFormat,
      ).toBytes().buffer.asUint8List(),
      equals(
        Uint8List.fromList(<int>[
          0,
          0,
          0,
          0,
          ...pixelFormat.toBytes().buffer.asUint8List(),
        ]).buffer.asUint8List(),
      ),
    );
  });
}
