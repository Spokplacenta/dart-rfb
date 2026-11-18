import 'dart:typed_data';

import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/encodings/pixel_converter.dart';

/// Decodes the Cursor pseudo-encoding (RFC 6143 §7.8.1).
///
/// The rectangle's x and y are the hotspot. Its data is `width * height`
/// pixels in the current pixel format, then a bitmask of
/// `floor((width + 7) / 8) * height` bytes, one bit per pixel, most
/// significant bit first, each row padded to a whole byte.
class CursorDecoder {
  CursorDecoder({required this.converter});

  /// Converts the cursor pixels to BGRA8888.
  final PixelConverter converter;

  /// The number of bytes of a [width] x [height] cursor on the wire.
  static int dataLength({
    required final int bytesPerPixel,
    required final int width,
    required final int height,
  }) =>
      width * height * bytesPerPixel + maskStride(width) * height;

  /// The number of bytes of one bitmask row.
  static int maskStride(final int width) => (width + 7) ~/ 8;

  /// Decodes [data] into a cursor with its hotspot at ([hotspotX], [hotspotY]).
  RemoteFrameBufferClientCursor decode({
    required final ByteData data,
    required final int width,
    required final int height,
    required final int hotspotX,
    required final int hotspotY,
  }) {
    final int bytesPerPixel = converter.bytesPerPixel;
    if (data.lengthInBytes <
        dataLength(
          bytesPerPixel: bytesPerPixel,
          width: width,
          height: height,
        )) {
      throw const FormatException('Cursor rectangle shorter than expected');
    }
    final int pixelCount = width * height;
    final Uint32List output = Uint32List(pixelCount);
    final Uint8List bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    converter.convertPixels(
      source: bytes,
      sourceOffset: 0,
      destination: output,
      pixelCount: pixelCount,
    );
    final int maskOffset = pixelCount * bytesPerPixel;
    final int stride = maskStride(width);
    for (int y = 0; y < height; y++) {
      final int rowMask = maskOffset + y * stride;
      for (int x = 0; x < width; x++) {
        if ((bytes[rowMask + (x >> 3)] >> (7 - (x & 7))) & 1 == 0) {
          // Fully transparent, colour included (premultiplied alpha).
          output[y * width + x] = 0;
        }
      }
    }
    return RemoteFrameBufferClientCursor(
      height: height,
      hotspotX: hotspotX,
      hotspotY: hotspotY,
      pixels: ByteData.sublistView(output),
      width: width,
    );
  }
}
