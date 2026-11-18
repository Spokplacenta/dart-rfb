import 'dart:io';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/hextile_decoder.dart';
import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/encodings/zlib_decoder.dart';
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

  PixelConverter get converter => PixelConverter(pixelFormat: pixelFormat);

  /// The pixel bytes (little endian) of [color].
  List<int> pixel(final int color) => <int>[
        for (int i = 0; i < pixelFormat.bitsPerPixel ~/ 8; i++)
          (values[color]! >> (8 * i)) & 0xFF,
      ];
}

const List<_Format> _formats = <_Format>[
  _Format('bgr233', RemoteFrameBufferPixelFormat.bgr233, <int, int>{
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

/// One deflate stream, flushed at the end of each rectangle, as a server
/// sends ZLib.
class _Deflater {
  final RawZLibFilter _filter = RawZLibFilter.deflateFilter();

  ByteData compress(final List<int> data) {
    _filter.process(data, 0, data.length);
    final BytesBuilder output = BytesBuilder();
    List<int>? chunk;
    while ((chunk = _filter.processed()) != null) {
      output.add(chunk!);
    }
    return ByteData.sublistView(output.takeBytes());
  }
}

List<int> _colours(final ByteData data) =>
    data.buffer.asUint32List(data.offsetInBytes, data.lengthInBytes ~/ 4);

void main() {
  for (final _Format format in _formats) {
    group(format.name, () {
      test('ZLib rectangles share one zlib stream', () {
        final _Deflater deflater = _Deflater();
        final ZlibDecoder decoder = ZlibDecoder(converter: format.converter);
        const List<int> first = <int>[_red, _green, _blue, _white];
        const List<int> second = <int>[_white, _blue, _green, _red];
        for (final List<int> colours in <List<int>>[first, second, first]) {
          expect(
            _colours(
              decoder.decode(
                compressed: deflater.compress(<int>[
                  for (final int colour in colours) ...format.pixel(colour),
                ]),
                width: 2,
                height: 2,
              ),
            ),
            colours,
          );
        }
      });

      test('Hextile tiles of every subencoding', () {
        final HextileDecoder decoder =
            HextileDecoder(converter: format.converter);
        // A 64x1 rectangle: four 16x1 tiles.
        final List<int> data = <int>[
          // Raw: the 16 pixels follow.
          HextileDecoder.raw,
          for (int i = 0; i < 16; i++) ...format.pixel(i.isEven ? _red : _blue),
          // Background only.
          HextileDecoder.backgroundSpecified,
          ...format.pixel(_green),
          // Background, foreground and two plain subrectangles: x 2 width 3,
          // then x 10 width 1.
          HextileDecoder.backgroundSpecified |
              HextileDecoder.foregroundSpecified |
              HextileDecoder.anySubrects,
          ...format.pixel(_black),
          ...format.pixel(_white),
          2,
          0x20, 0x20, //
          0xA0, 0x00,
          // The previous background, one coloured subrectangle at x 15.
          HextileDecoder.anySubrects | HextileDecoder.subrectsColoured,
          1,
          ...format.pixel(_red),
          0xF0, 0x00,
        ];
        final List<int> colours = _colours(
          decoder.decode(
            data: ByteData.sublistView(Uint8List.fromList(data)),
            width: 64,
            height: 1,
          ),
        );
        expect(colours.sublist(0, 16), <int>[
          for (int i = 0; i < 16; i++) i.isEven ? _red : _blue,
        ]);
        expect(colours.sublist(16, 32), List<int>.filled(16, _green));
        expect(colours.sublist(32, 48), <int>[
          for (int x = 0; x < 16; x++)
            (x >= 2 && x < 5) || x == 10 ? _white : _black,
        ]);
        expect(colours.sublist(48, 64), <int>[
          ...List<int>.filled(15, _black),
          _red,
        ]);
      });
    });
  }

  group('ZLib', () {
    final _Format format = _formats[1];

    test('a large rectangle is inflated whole', () {
      final _Deflater deflater = _Deflater();
      final ZlibDecoder decoder = ZlibDecoder(converter: format.converter);
      final List<int> colours = <int>[
        for (int i = 0; i < 64 * 64; i++) <int>[_red, _green, _blue][i % 3],
      ];
      final ByteData compressed = deflater.compress(<int>[
        for (final int colour in colours) ...format.pixel(colour),
      ]);
      expect(
        _colours(decoder.decode(compressed: compressed, width: 64, height: 64)),
        colours,
      );
    });

    test('an empty rectangle reads no data', () {
      final ZlibDecoder decoder = ZlibDecoder(converter: format.converter);
      expect(
        decoder
            .decode(compressed: ByteData(0), width: 0, height: 0)
            .lengthInBytes,
        0,
      );
    });

    test('too few inflated bytes are rejected', () {
      final ZlibDecoder decoder = ZlibDecoder(converter: format.converter);
      expect(
        () => decoder.decode(
          compressed: _Deflater().compress(format.pixel(_red)),
          width: 2,
          height: 1,
        ),
        throwsFormatException,
      );
    });
  });

  group('Hextile', () {
    final _Format format = _formats[2];
    final HextileDecoder decoder = HextileDecoder(converter: format.converter);

    List<int> decode(final List<int> data, final int width, final int height) =>
        _colours(
          decoder.decode(
            data: ByteData.sublistView(Uint8List.fromList(data)),
            width: width,
            height: height,
          ),
        );

    test('background and foreground carry over to the next tiles', () {
      // 48x1: three tiles.
      expect(
        decode(
          <int>[
            HextileDecoder.backgroundSpecified |
                HextileDecoder.foregroundSpecified,
            ...format.pixel(_blue),
            ...format.pixel(_red),
            // Same background and foreground, a subrectangle at x 0.
            HextileDecoder.anySubrects,
            1,
            0x00, 0x00,
            // A raw tile does not change them.
            HextileDecoder.raw,
            for (int i = 0; i < 16; i++) ...format.pixel(_white),
          ],
          48,
          1,
        ),
        <int>[
          ...List<int>.filled(16, _blue),
          _red,
          ...List<int>.filled(15, _blue),
          ...List<int>.filled(16, _white),
        ],
      );
    });

    test('a raw tile keeps background and foreground for the next one', () {
      expect(
        decode(
          <int>[
            HextileDecoder.backgroundSpecified |
                HextileDecoder.foregroundSpecified,
            ...format.pixel(_green),
            ...format.pixel(_red),
            HextileDecoder.raw,
            for (int i = 0; i < 16; i++) ...format.pixel(_white),
            HextileDecoder.anySubrects,
            1,
            0x10,
            0x00,
          ],
          48,
          1,
        ).sublist(32),
        <int>[_green, _red, ...List<int>.filled(14, _green)],
      );
    });

    test('edge tiles are smaller than 16x16', () {
      // 20x18: tiles 16x16, 4x16, 16x2 and 4x2.
      final List<int> colours = decode(
        <int>[
          for (final int colour in <int>[_red, _green, _blue, _white]) ...<int>[
            HextileDecoder.backgroundSpecified,
            ...format.pixel(colour),
          ],
        ],
        20,
        18,
      );
      int at(final int x, final int y) => colours[y * 20 + x];
      expect(at(0, 0), _red);
      expect(at(15, 15), _red);
      expect(at(16, 0), _green);
      expect(at(19, 15), _green);
      expect(at(0, 16), _blue);
      expect(at(15, 17), _blue);
      expect(at(16, 16), _white);
      expect(at(19, 17), _white);
    });

    test('a raw edge tile reads only its own pixels', () {
      // 18x2: a 16x2 background tile, then a 2x2 raw tile.
      expect(
        decode(
          <int>[
            HextileDecoder.backgroundSpecified,
            ...format.pixel(_black),
            HextileDecoder.raw,
            ...format.pixel(_red),
            ...format.pixel(_green),
            ...format.pixel(_blue),
            ...format.pixel(_white),
          ],
          18,
          2,
        ),
        <int>[
          ...List<int>.filled(16, _black), _red, _green, //
          ...List<int>.filled(16, _black), _blue, _white,
        ],
      );
    });

    test('subrectangles cover their full width and height', () {
      // A 4x4 white square at (2, 3) in a 16x16 tile.
      final List<int> colours = decode(
        <int>[
          HextileDecoder.backgroundSpecified |
              HextileDecoder.foregroundSpecified |
              HextileDecoder.anySubrects,
          ...format.pixel(_black),
          ...format.pixel(_white),
          1,
          0x23,
          0x33,
        ],
        16,
        16,
      );
      for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
          expect(
            colours[y * 16 + x],
            x >= 2 && x < 6 && y >= 3 && y < 7 ? _white : _black,
            reason: '($x, $y)',
          );
        }
      }
    });

    test('a big rectangle', () {
      // 800x480: 1500 tiles, alternating backgrounds.
      final List<int> data = <int>[
        for (int i = 0; i < 50 * 30; i++) ...<int>[
          HextileDecoder.backgroundSpecified,
          ...format.pixel(i.isEven ? _red : _blue),
        ],
      ];
      final List<int> colours = decode(data, 800, 480);
      expect(colours, hasLength(800 * 480));
      expect(colours[0], _red);
      expect(colours[16], _blue);
      expect(colours[479 * 800 + 799], _blue);
    });

    test('truncated data is rejected', () {
      expect(
        () => decode(
          <int>[HextileDecoder.raw, ...format.pixel(_red)],
          16,
          16,
        ),
        throwsFormatException,
      );
    });
  });
}
