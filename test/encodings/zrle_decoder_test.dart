import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  final RemoteFrameBufferPixelFormat pixelFormat =
      RemoteFrameBufferPixelFormat.bgra8888;
  final ZrleDecoder decoder = ZrleDecoder(pixelFormat: pixelFormat);

  test('decodes raw tile', () {
    final ByteData zrleData = _buildZrleData(
      <int>[
        0, // raw tile
        0x01,
        0x02,
        0x03,
        0x10,
        0x20,
        0x30,
      ],
    );
    final ByteData output = decoder.decode(
      zrleData: zrleData,
      width: 2,
      height: 1,
    );
    expect(
      output.buffer.asUint8List(),
      equals(
        Uint8List.fromList(
          <int>[
            0x01,
            0x02,
            0x03,
            0x00,
            0x10,
            0x20,
            0x30,
            0x00,
          ],
        ),
      ),
    );
  });

  test('decodes plain RLE tile', () {
    final ByteData zrleData = _buildZrleData(
      <int>[
        128, // plain RLE tile
        0x0A,
        0x0B,
        0x0C, // color
        0x01, // run length = 1 (default) + 1 => 2 pixels
      ],
    );
    final ByteData output = decoder.decode(
      zrleData: zrleData,
      width: 2,
      height: 1,
    );
    expect(
      output.buffer.asUint8List(),
      equals(
        Uint8List.fromList(
          <int>[
            0x0A,
            0x0B,
            0x0C,
            0x00,
            0x0A,
            0x0B,
            0x0C,
            0x00,
          ],
        ),
      ),
    );
  });
}

ByteData _buildZrleData(final List<int> decompressedBytes) {
  final Uint8List compressed =
      Uint8List.fromList(ZLibCodec().encode(decompressedBytes));
  final BytesBuilder builder = BytesBuilder()
    ..add(
      (ByteData(4)..setUint32(0, compressed.length)).buffer.asUint8List(),
    )
    ..add(compressed);
  return ByteData.sublistView(builder.toBytes());
}

