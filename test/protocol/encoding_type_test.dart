import 'dart:typed_data';

import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  test('Encoding type from bytes works', () {
    expect(
      RemoteFrameBufferEncodingType.fromBytes(
        bytes: ByteData(4)..setInt32(0, 0),
      ),
      equals(const RemoteFrameBufferEncodingType.raw()),
    );
    expect(
      RemoteFrameBufferEncodingType.fromBytes(
        bytes: ByteData(4)..setInt32(0, 16),
      ),
      equals(const RemoteFrameBufferEncodingType.zrle()),
    );
    expect(
      RemoteFrameBufferEncodingType.fromBytes(
        bytes: ByteData(4)..setInt32(0, -239),
      ),
      equals(const RemoteFrameBufferEncodingType.cursor()),
    );
    expect(
      RemoteFrameBufferEncodingType.fromBytes(
        bytes: ByteData(4)..setInt32(0, 5),
      ),
      equals(const RemoteFrameBufferEncodingType.hextile()),
    );
    expect(
      RemoteFrameBufferEncodingType.fromBytes(
        bytes: ByteData(4)..setInt32(0, 6),
      ),
      equals(const RemoteFrameBufferEncodingType.zlib()),
    );
    final RemoteFrameBufferEncodingType encodingType =
        RemoteFrameBufferEncodingType.fromBytes(
      bytes: ByteData(4)..setInt32(0, -1),
    );
    expect(encodingType, isA<RemoteFrameBufferEncodingTypeUnsupported>());
    expect(
      (encodingType as RemoteFrameBufferEncodingTypeUnsupported)
          .bytes
          .buffer
          .asUint8List(),
      (ByteData(4)..setInt32(0, -1)).buffer.asUint8List(),
    );
  });

  test('Encoding type to bytes works', () {
    expect(
      const RemoteFrameBufferEncodingType.raw().toBytes().buffer.asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, 0)).buffer.asUint8List(),
      ),
    );
    expect(
      const RemoteFrameBufferEncodingType.copyRect()
          .toBytes()
          .buffer
          .asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, 1)).buffer.asUint8List(),
      ),
    );
    expect(
      const RemoteFrameBufferEncodingType.zrle().toBytes().buffer.asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, 16)).buffer.asUint8List(),
      ),
    );
    expect(
      const RemoteFrameBufferEncodingType.cursor()
          .toBytes()
          .buffer
          .asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, -239)).buffer.asUint8List(),
      ),
    );
    expect(
      const RemoteFrameBufferEncodingType.hextile()
          .toBytes()
          .buffer
          .asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, 5)).buffer.asUint8List(),
      ),
    );
    expect(
      const RemoteFrameBufferEncodingType.zlib().toBytes().buffer.asUint8List(),
      equals(
        (ByteData(4)..setInt32(0, 6)).buffer.asUint8List(),
      ),
    );
  });
}
