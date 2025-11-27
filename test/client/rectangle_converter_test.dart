import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_rfb/src/client/rectangle_converter.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:dart_rfb/src/protocol/frame_buffer_update_message.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:logging/logging.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  final RemoteFrameBufferRectangleConverter converter =
      RemoteFrameBufferRectangleConverter(
    logger: Logger('RectangleConverterTest'),
  );

  test('convert decodes ZRLE rectangle when decoder available', () {
    final ByteData zrleData = _buildZrleData(
      <int>[
        0,
        0xAA,
        0xBB,
        0xCC,
      ],
    );
    final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle =
        RemoteFrameBufferFrameBufferUpdateMessageRectangle(
      encodingType: const RemoteFrameBufferEncodingType.zrle(),
      height: 1,
      pixelData: zrleData,
      width: 1,
      x: 0,
      y: 0,
    );
    final RemoteFrameBufferClientUpdateRectangle result = converter.convert(
      rectangle: rectangle,
      zrleDecoder:
          ZrleDecoder(pixelFormat: RemoteFrameBufferPixelFormat.bgra8888),
    );
    expect(result.encodingType, equals(const RemoteFrameBufferEncodingType.raw()));
    expect(
      result.byteData.buffer.asUint8List(),
      equals(
        Uint8List.fromList(
          <int>[0xAA, 0xBB, 0xCC, 0x00],
        ),
      ),
    );
  });

  test('convert leaves rectangle untouched when decoder missing', () {
    final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle =
        RemoteFrameBufferFrameBufferUpdateMessageRectangle(
      encodingType: const RemoteFrameBufferEncodingType.zrle(),
      height: 1,
      pixelData: ByteData(4)..setUint32(0, 0),
      width: 1,
      x: 0,
      y: 0,
    );
    final RemoteFrameBufferClientUpdateRectangle result = converter.convert(
      rectangle: rectangle,
      zrleDecoder: null,
    );
    expect(
      result.encodingType,
      equals(const RemoteFrameBufferEncodingType.zrle()),
    );
    expect(result.byteData.buffer.asUint8List(), equals(rectangle.pixelData.buffer.asUint8List()));
  });
}

ByteData _buildZrleData(final List<int> decompressed) {
  final Uint8List compressed =
      Uint8List.fromList(ZLibEncoder().convert(decompressed));
  final BytesBuilder builder = BytesBuilder()
    ..add(
      (ByteData(4)..setUint32(0, compressed.length)).buffer.asUint8List(),
    )
    ..add(compressed);
  return ByteData.sublistView(builder.toBytes());
}

