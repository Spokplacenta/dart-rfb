import 'dart:io';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/pixel_converter.dart';

/// Decoder for ZLib rectangles: Raw pixels in the current pixel format,
/// compressed with zlib.
///
/// Like ZRLE, ZLib uses one zlib stream for the whole connection, but its own
/// one: the [_inflater] must be reused for every rectangle, in the order they
/// arrive. The output is opaque BGRA8888, 4 bytes per pixel.
///
/// See: https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#zlib-encoding
class ZlibDecoder {
  ZlibDecoder({required final PixelConverter converter})
      : _converter = converter,
        _inflater = RawZLibFilter.inflateFilter();

  final PixelConverter _converter;
  RawZLibFilter _inflater;

  /// Reset the zlib stream. Call this when starting a new VNC session.
  void reset() {
    _inflater = RawZLibFilter.inflateFilter();
  }

  /// Decode [compressed] (the bytes after the length) of a [width] x [height]
  /// rectangle into opaque BGRA8888 pixel bytes.
  ByteData decode({
    required final ByteData compressed,
    required final int width,
    required final int height,
  }) {
    final int expected = width * height * _converter.bytesPerPixel;
    final Uint8List pixels = compressed.lengthInBytes == 0
        ? Uint8List(0)
        : _inflate(
            compressed.buffer.asUint8List(
              compressed.offsetInBytes,
              compressed.lengthInBytes,
            ),
          );
    if (pixels.length < expected) {
      throw FormatException(
        'ZLib rectangle inflated to ${pixels.length} bytes, $expected expected',
      );
    }
    return _converter.convertRaw(
      pixelData: ByteData.sublistView(pixels, 0, expected),
      width: width,
      height: height,
    );
  }

  /// Inflates [compressed] without ending the stream: the server flushes it
  /// at the end of each rectangle.
  Uint8List _inflate(final Uint8List compressed) {
    _inflater.process(compressed, 0, compressed.length);
    final BytesBuilder output = BytesBuilder(copy: false);
    List<int>? chunk;
    while ((chunk = _inflater.processed(flush: true)) != null) {
      output.add(chunk!);
    }
    return output.takeBytes();
  }
}
