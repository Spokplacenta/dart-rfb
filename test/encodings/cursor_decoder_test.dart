import 'dart:typed_data';

import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/encodings/cursor_decoder.dart';
import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:test/test.dart';

// BGRA8888 colours, as little-endian Uint32 values.
const int _transparent = 0x00000000;
const int _white = 0xFFFFFFFF;
const int _red = 0xFFFF0000;
const int _blue = 0xFF0000FF;

/// The pixel values of the colours in one pixel format.
class _Format {
  const _Format(this.name, this.pixelFormat, this.values);

  final String name;
  final RemoteFrameBufferPixelFormat pixelFormat;
  final Map<int, int> values;

  /// The wire bytes (little endian) of [color].
  List<int> pixel(final int color) => <int>[
        for (int i = 0; i < pixelFormat.bitsPerPixel ~/ 8; i++)
          (values[color]! >> (8 * i)) & 0xFF,
      ];
}

const List<_Format> _formats = <_Format>[
  _Format('bgr233', RemoteFrameBufferPixelFormat.bgr233, <int, int>{
    _white: 0x3F,
    _red: 0x30,
    _blue: 0x03,
  }),
  _Format('rgb565', RemoteFrameBufferPixelFormat.rgb565, <int, int>{
    _white: 0xFFFF,
    _red: 0xF800,
    _blue: 0x001F,
  }),
  _Format('bgra8888', RemoteFrameBufferPixelFormat.bgra8888, <int, int>{
    _white: 0xFFFFFF,
    _red: 0xFF0000,
    _blue: 0x0000FF,
  }),
];

RemoteFrameBufferClientCursor _decode(
  final _Format format, {
  required final List<int> colors,
  required final List<int> mask,
  required final int width,
  required final int height,
  final int hotspotX = 0,
  final int hotspotY = 0,
}) =>
    CursorDecoder(
      converter: PixelConverter(pixelFormat: format.pixelFormat),
    ).decode(
      data: ByteData.sublistView(
        Uint8List.fromList(<int>[
          for (final int color in colors) ...format.pixel(color),
          ...mask,
        ]),
      ),
      width: width,
      height: height,
      hotspotX: hotspotX,
      hotspotY: hotspotY,
    );

List<int> _pixels(final RemoteFrameBufferClientCursor cursor) =>
    Uint32List.sublistView(cursor.pixels);

void main() {
  for (final _Format format in _formats) {
    group(format.name, () {
      test('masked pixels are transparent, the others opaque', () {
        // 3x2: the mask hides the middle of the first row and the start of
        // the second one.
        final RemoteFrameBufferClientCursor cursor = _decode(
          format,
          colors: <int>[_red, _white, _blue, _blue, _red, _white],
          mask: <int>[0xA0, 0x60], // 101 / 011, then padding bits
          width: 3,
          height: 2,
          hotspotX: 1,
          hotspotY: 2,
        );
        expect(cursor.width, 3);
        expect(cursor.height, 2);
        expect(cursor.hotspotX, 1);
        expect(cursor.hotspotY, 2);
        expect(cursor.isVisible, isTrue);
        expect(_pixels(cursor), <int>[
          _red, _transparent, _blue, //
          _transparent, _red, _white,
        ]);
      });
    });
  }

  test('width not a multiple of 8 uses whole mask bytes per row', () {
    // 10x2: each mask row is 2 bytes. Row 0 shows pixels 0 and 9 only, row 1
    // shows all of them.
    final RemoteFrameBufferClientCursor cursor = _decode(
      _formats.last,
      colors: List<int>.filled(20, _white),
      mask: <int>[0x80, 0x40, 0xFF, 0xC0],
      width: 10,
      height: 2,
    );
    expect(_pixels(cursor), <int>[
      _white, ...List<int>.filled(8, _transparent), _white, //
      ...List<int>.filled(10, _white),
    ]);
  });

  test('padding bits of the mask are ignored', () {
    final RemoteFrameBufferClientCursor cursor = _decode(
      _formats.last,
      colors: <int>[_red],
      mask: <int>[0xFF],
      width: 1,
      height: 1,
    );
    expect(_pixels(cursor), <int>[_red]);
  });

  test('a 0x0 cursor is invisible', () {
    final RemoteFrameBufferClientCursor cursor = _decode(
      _formats.last,
      colors: <int>[],
      mask: <int>[],
      width: 0,
      height: 0,
    );
    expect(cursor.isVisible, isFalse);
    expect(cursor.pixels.lengthInBytes, 0);
  });

  test('data length counts the pixels and the mask', () {
    expect(
      CursorDecoder.dataLength(bytesPerPixel: 2, width: 10, height: 3),
      10 * 3 * 2 + 2 * 3,
    );
    expect(
      CursorDecoder.dataLength(bytesPerPixel: 4, width: 0, height: 0),
      0,
    );
  });

  test('short data is rejected', () {
    expect(
      () => _decode(
        _formats.last,
        colors: <int>[_red],
        mask: <int>[],
        width: 1,
        height: 1,
      ),
      throwsFormatException,
    );
  });
}
