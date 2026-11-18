import 'dart:math';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/pixel_converter.dart';

/// Decoder for Hextile rectangles (RFC 6143 §7.7.4).
///
/// The rectangle is split into 16x16 tiles, left to right then top to
/// bottom; the tiles of the right and bottom edges may be smaller. Each tile
/// starts with a subencoding mask:
///
/// - [raw]: the tile's pixels follow, the other bits are ignored;
/// - [backgroundSpecified]: a background pixel follows, otherwise the
///   previous tile's one is kept;
/// - [foregroundSpecified]: a foreground pixel follows, otherwise the
///   previous tile's one is kept;
/// - [anySubrects]: a count of subrectangles follows, then for each one,
///   with [subrectsColoured], its pixel, then its position and size in two
///   bytes (x << 4 | y, (w - 1) << 4 | (h - 1)). Without [subrectsColoured],
///   subrectangles are in the foreground colour.
///
/// The background and foreground carry over from tile to tile within one
/// rectangle only. The output is opaque BGRA8888, written directly into a
/// [Uint32List].
class HextileDecoder {
  HextileDecoder({required final PixelConverter converter})
      : _converter = converter;

  static const int raw = 1;
  static const int backgroundSpecified = 2;
  static const int foregroundSpecified = 4;
  static const int anySubrects = 8;
  static const int subrectsColoured = 16;

  /// Size of a tile's side.
  static const int tileSize = 16;

  final PixelConverter _converter;

  /// The length of the tile data following a subencoding mask [subencoding],
  /// up to and including the subrectangle count, for a [tileWidth] x
  /// [tileHeight] tile at [bytesPerPixel].
  static int tileHeaderLength({
    required final int subencoding,
    required final int bytesPerPixel,
    required final int tileWidth,
    required final int tileHeight,
  }) {
    if (subencoding & raw != 0) {
      return tileWidth * tileHeight * bytesPerPixel;
    }
    return (subencoding & backgroundSpecified != 0 ? bytesPerPixel : 0) +
        (subencoding & foregroundSpecified != 0 ? bytesPerPixel : 0) +
        (subencoding & anySubrects != 0 ? 1 : 0);
  }

  /// The length of one subrectangle for a tile of [subencoding].
  static int subrectLength({
    required final int subencoding,
    required final int bytesPerPixel,
  }) =>
      subencoding & subrectsColoured != 0 ? bytesPerPixel + 2 : 2;

  /// Decode the Hextile [data] of a [width] x [height] rectangle into opaque
  /// BGRA8888 pixel bytes.
  ByteData decode({
    required final ByteData data,
    required final int width,
    required final int height,
  }) {
    final Uint8List bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final int bpp = _converter.bytesPerPixel;
    final Uint32List output = Uint32List(width * height);
    // Undefined until a tile specifies them: opaque black.
    int background = 0xFF000000;
    int foreground = 0xFF000000;
    int offset = 0;

    void need(final int length) {
      if (offset + length > bytes.length) {
        throw const FormatException('Hextile rectangle shorter than expected');
      }
    }

    int readPixel() {
      final int value =
          _converter.convert(_converter.readPixel(bytes, offset, bpp));
      offset += bpp;
      return value;
    }

    for (int tileY = 0; tileY < height; tileY += tileSize) {
      final int tileHeight = min(tileSize, height - tileY);
      for (int tileX = 0; tileX < width; tileX += tileSize) {
        final int tileWidth = min(tileSize, width - tileX);
        need(1);
        final int subencoding = bytes[offset++];
        if (subencoding & raw != 0) {
          need(tileWidth * tileHeight * bpp);
          for (int y = 0; y < tileHeight; y++) {
            _converter.convertPixels(
              source: bytes,
              sourceOffset: offset,
              destination: Uint32List.sublistView(
                output,
                (tileY + y) * width + tileX,
              ),
              pixelCount: tileWidth,
            );
            offset += tileWidth * bpp;
          }
          continue;
        }
        need(
          tileHeaderLength(
            subencoding: subencoding,
            bytesPerPixel: bpp,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
          ),
        );
        if (subencoding & backgroundSpecified != 0) {
          background = readPixel();
        }
        if (subencoding & foregroundSpecified != 0) {
          foreground = readPixel();
        }
        for (int y = 0; y < tileHeight; y++) {
          final int start = (tileY + y) * width + tileX;
          output.fillRange(start, start + tileWidth, background);
        }
        if (subencoding & anySubrects == 0) {
          continue;
        }
        final int count = bytes[offset++];
        final bool coloured = subencoding & subrectsColoured != 0;
        final int subrect =
            subrectLength(subencoding: subencoding, bytesPerPixel: bpp);
        need(count * subrect);
        for (int i = 0; i < count; i++) {
          final int colour = coloured ? readPixel() : foreground;
          final int position = bytes[offset++];
          final int size = bytes[offset++];
          final int x = position >> 4;
          final int y = position & 0x0F;
          final int w = min((size >> 4) + 1, tileWidth - x);
          final int h = min((size & 0x0F) + 1, tileHeight - y);
          if (w <= 0 || h <= 0) {
            // Outside the tile: a bad server, but no reason to fail.
            continue;
          }
          for (int row = 0; row < h; row++) {
            final int start = (tileY + y + row) * width + tileX + x;
            output.fillRange(start, start + w, colour);
          }
        }
      }
    }
    return ByteData.sublistView(output);
  }
}
