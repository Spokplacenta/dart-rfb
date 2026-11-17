import 'dart:io';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:test/test.dart';

// Opaque BGRA8888 colours, as little-endian Uint32 values.
const int _black = 0xFF000000;
const int _white = 0xFFFFFFFF;
const int _red = 0xFFFF0000;
const int _green = 0xFF00FF00;
const int _blue = 0xFF0000FF;

/// The pixel values of the primary colours in one pixel format.
class _Format {
  const _Format(this.name, this.pixelFormat, this.values);

  final String name;
  final RemoteFrameBufferPixelFormat pixelFormat;

  /// Wire pixel value of each BGRA colour.
  final Map<int, int> values;

  int get cpixelSize => ZrleDecoder.cpixelSize(pixelFormat);

  /// The CPIXEL bytes (little endian) of [color].
  List<int> cpixel(final int color) => <int>[
        for (int i = 0; i < cpixelSize; i++) (values[color]! >> (8 * i)) & 0xFF,
      ];

  /// The Raw pixel bytes (little endian) of [color].
  List<int> pixel(final int color) => <int>[
        for (int i = 0; i < pixelFormat.bitsPerPixel ~/ 8; i++)
          (values[color]! >> (8 * i)) & 0xFF,
      ];
}

const List<_Format> _formats = <_Format>[
  _Format('bgr233 (2 bits per component)',
      RemoteFrameBufferPixelFormat.bgr233, <int, int>{
    _black: 0x00,
    _white: 0x3F,
    _red: 0x30,
    _green: 0x0C,
    _blue: 0x03,
  }),
  _Format('rgb565', RemoteFrameBufferPixelFormat.rgb565, <int, int>{
    _black: 0x0000,
    _white: 0xFFFF,
    _red: 0xF800,
    _green: 0x07E0,
    _blue: 0x001F,
  }),
  _Format('bgra8888', RemoteFrameBufferPixelFormat.bgra8888, <int, int>{
    _black: 0x000000,
    _white: 0xFFFFFF,
    _red: 0xFF0000,
    _green: 0x00FF00,
    _blue: 0x0000FF,
  }),
];

/// Decodes one 4x2 ZRLE tile made of [tile] (uncompressed bytes).
List<int> _decodeTile(final _Format format, final List<int> tile) {
  final Uint8List compressed = Uint8List.fromList(ZLibCodec().encode(tile));
  final ByteData zrleData = ByteData(4 + compressed.length)
    ..setUint32(0, compressed.length);
  zrleData.buffer.asUint8List(4).setAll(0, compressed);
  final ByteData output = ZrleDecoder(pixelFormat: format.pixelFormat)
      .decode(zrleData: zrleData, width: 4, height: 2);
  expect(output.lengthInBytes, 4 * 2 * 4);
  return output.buffer.asUint32List(output.offsetInBytes, 8);
}

void main() {
  test('CPIXEL size depends on the format', () {
    expect(ZrleDecoder.cpixelSize(RemoteFrameBufferPixelFormat.bgr233), 1);
    expect(ZrleDecoder.cpixelSize(RemoteFrameBufferPixelFormat.rgb565), 2);
    expect(ZrleDecoder.cpixelSize(RemoteFrameBufferPixelFormat.bgra8888), 3);
  });

  for (final _Format format in _formats) {
    group(format.name, () {
      test('ZRLE solid tile', () {
        expect(
          _decodeTile(format, <int>[1, ...format.cpixel(_red)]),
          List<int>.filled(8, _red),
        );
      });

      test('ZRLE raw tile', () {
        const List<int> colors = <int>[
          _black, _white, _red, _green, //
          _blue, _red, _white, _black, //
        ];
        expect(
          _decodeTile(format, <int>[
            0,
            for (final int color in colors) ...format.cpixel(color),
          ]),
          colors,
        );
      });

      test('ZRLE packed palette tile', () {
        expect(
          _decodeTile(format, <int>[
            2, // palette of 2 colours, 1 bit per pixel
            ...format.cpixel(_red),
            ...format.cpixel(_blue),
            0x50, // row 0: 0 1 0 1
            0xC0, // row 1: 1 1 0 0
          ]),
          <int>[_red, _blue, _red, _blue, _blue, _blue, _red, _red],
        );
      });

      test('ZRLE plain RLE tile, runs across rows', () {
        expect(
          _decodeTile(format, <int>[
            128,
            ...format.cpixel(_green),
            4, // 5 pixels
            ...format.cpixel(_white),
            2, // 3 pixels
          ]),
          <int>[
            _green, _green, _green, _green, //
            _green, _white, _white, _white, //
          ],
        );
      });

      test('ZRLE palette RLE tile', () {
        expect(
          _decodeTile(format, <int>[
            130, // palette of 2 colours
            ...format.cpixel(_black),
            ...format.cpixel(_white),
            0x80, 2, // black, 3 pixels
            1, // white, 1 pixel
            0x81, 3, // white, 4 pixels
          ]),
          <int>[
            _black, _black, _black, _white, //
            _white, _white, _white, _white, //
          ],
        );
      });

      test('Raw pixels are converted to BGRA8888', () {
        const List<int> colors = <int>[_black, _white, _red, _green, _blue];
        final ByteData output =
            PixelConverter(pixelFormat: format.pixelFormat).convertRaw(
          pixelData: ByteData.sublistView(
            Uint8List.fromList(<int>[
              for (final int color in colors) ...format.pixel(color),
            ]),
          ),
          width: 5,
          height: 1,
        );
        expect(output.buffer.asUint32List(output.offsetInBytes, 5), colors);
      });

      test('extreme component values map to 0 and 255', () {
        final RemoteFrameBufferPixelFormat f = format.pixelFormat;
        final PixelConverter converter = PixelConverter(pixelFormat: f);
        expect(converter.convert(0), _black);
        expect(converter.convert(f.redMax << f.redShift), _red);
        expect(converter.convert(f.greenMax << f.greenShift), _green);
        expect(converter.convert(f.blueMax << f.blueShift), _blue);
        expect(
          converter.convert(
            f.redMax << f.redShift |
                f.greenMax << f.greenShift |
                f.blueMax << f.blueShift,
          ),
          _white,
        );
      });
    });
  }

  test('rgb565 middle values are scaled and rounded', () {
    final PixelConverter converter =
        PixelConverter(pixelFormat: RemoteFrameBufferPixelFormat.rgb565);
    // red 16/31 -> 132, green 32/63 -> 130, blue 1/31 -> 8
    expect(converter.convert(16 << 11 | 32 << 5 | 1), 0xFF848208);
  });

  test('unsupported pixel formats are rejected', () {
    expect(
      () => PixelConverter(
        pixelFormat:
            RemoteFrameBufferPixelFormat.rgb565.copyWith(trueColor: false),
      ),
      throwsArgumentError,
    );
    expect(
      () => PixelConverter(
        pixelFormat:
            RemoteFrameBufferPixelFormat.rgb565.copyWith(bitsPerPixel: 24),
      ),
      throwsArgumentError,
    );
  });
}
