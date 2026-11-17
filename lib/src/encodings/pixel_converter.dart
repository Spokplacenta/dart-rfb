import 'dart:typed_data';

import 'package:dart_rfb/src/protocol/pixel_format.dart';

/// Converts pixels of a true colour [RemoteFrameBufferPixelFormat] into
/// opaque BGRA8888 (Flutter's `PixelFormat.bgra8888`), one `Uint32` per pixel.
///
/// 8 and 16 bpp pixel values go through a lookup table built once; 32 bpp
/// values are converted directly.
class PixelConverter {
  PixelConverter({required this.pixelFormat})
      : bytesPerPixel = pixelFormat.bitsPerPixel ~/ 8 {
    if (!pixelFormat.trueColor) {
      throw ArgumentError.value(
        pixelFormat,
        'pixelFormat',
        'Only true colour pixel formats are supported',
      );
    }
    if (bytesPerPixel != 1 && bytesPerPixel != 2 && bytesPerPixel != 4) {
      throw ArgumentError.value(
        pixelFormat.bitsPerPixel,
        'pixelFormat.bitsPerPixel',
        'Only 8, 16 and 32 bits per pixel are supported',
      );
    }
    if (bytesPerPixel <= 2) {
      final Uint32List table = Uint32List(1 << (bytesPerPixel * 8));
      for (int value = 0; value < table.length; value++) {
        table[value] = _compute(value);
      }
      _table = table;
    }
  }

  /// The format of the pixels to convert.
  final RemoteFrameBufferPixelFormat pixelFormat;

  /// Size of one pixel in [pixelFormat].
  final int bytesPerPixel;

  Uint32List? _table;

  /// The opaque BGRA8888 value, as a little-endian `Uint32`, of the pixel
  /// [value] read from the wire.
  int convert(final int value) {
    final Uint32List? table = _table;
    return table != null ? table[value] : _compute(value);
  }

  /// Converts the [pixelCount] pixels of [source], from [sourceOffset], into
  /// [destination].
  void convertPixels({
    required final Uint8List source,
    required final int sourceOffset,
    required final Uint32List destination,
    required final int pixelCount,
  }) {
    int offset = sourceOffset;
    for (int i = 0; i < pixelCount; i++) {
      destination[i] = convert(readPixel(source, offset, bytesPerPixel));
      offset += bytesPerPixel;
    }
  }

  /// Converts the Raw pixel data of a [width] x [height] rectangle into opaque
  /// BGRA8888 bytes.
  ByteData convertRaw({
    required final ByteData pixelData,
    required final int width,
    required final int height,
  }) {
    final int pixelCount = width * height;
    if (pixelData.lengthInBytes < pixelCount * bytesPerPixel) {
      throw const FormatException('Raw rectangle shorter than expected');
    }
    final Uint32List output = Uint32List(pixelCount);
    convertPixels(
      source: pixelData.buffer.asUint8List(
        pixelData.offsetInBytes,
        pixelData.lengthInBytes,
      ),
      sourceOffset: 0,
      destination: output,
      pixelCount: pixelCount,
    );
    return ByteData.sublistView(output);
  }

  /// Reads a pixel value of [size] bytes at [offset], in [pixelFormat]'s
  /// byte order.
  int readPixel(final Uint8List bytes, final int offset, final int size) {
    switch (size) {
      case 1:
        return bytes[offset];
      case 2:
        return pixelFormat.bigEndian
            ? bytes[offset] << 8 | bytes[offset + 1]
            : bytes[offset] | bytes[offset + 1] << 8;
      case 3:
        return pixelFormat.bigEndian
            ? bytes[offset] << 16 | bytes[offset + 1] << 8 | bytes[offset + 2]
            : bytes[offset] | bytes[offset + 1] << 8 | bytes[offset + 2] << 16;
      default:
        return pixelFormat.bigEndian
            ? bytes[offset] << 24 |
                bytes[offset + 1] << 16 |
                bytes[offset + 2] << 8 |
                bytes[offset + 3]
            : bytes[offset] |
                bytes[offset + 1] << 8 |
                bytes[offset + 2] << 16 |
                bytes[offset + 3] << 24;
    }
  }

  int _compute(final int value) {
    final int red = _scale(
      (value >> pixelFormat.redShift) & pixelFormat.redMax,
      pixelFormat.redMax,
    );
    final int green = _scale(
      (value >> pixelFormat.greenShift) & pixelFormat.greenMax,
      pixelFormat.greenMax,
    );
    final int blue = _scale(
      (value >> pixelFormat.blueShift) & pixelFormat.blueMax,
      pixelFormat.blueMax,
    );
    // Little-endian bytes B, G, R, A.
    return 0xFF000000 | red << 16 | green << 8 | blue;
  }

  /// Scales [component] from 0..[max] to 0..255, rounded.
  static int _scale(final int component, final int max) => max == 255
      ? component
      : max == 0
          ? 0
          : (component * 255 + max ~/ 2) ~/ max;
}
