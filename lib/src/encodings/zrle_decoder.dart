import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_rfb/src/protocol/pixel_format.dart';

/// Decoder for ZRLE rectangles (see RFC 6143 §7.7.6.9).
///
/// The decoder currently assumes little-endian pixel formats, which matches the
/// `bgra8888` format negotiated by the client.
///
/// IMPORTANT: ZRLE uses a continuous zlib stream across all rectangles in a
/// session. The [_inflater] must be reused for all decode() calls. Call
/// [reset()] only when starting a new VNC session.
class ZrleDecoder {
  ZrleDecoder({
    required final RemoteFrameBufferPixelFormat pixelFormat,
  })  : _pixelFormat = pixelFormat,
        _bytesPerPixel = (pixelFormat.bitsPerPixel / 8).ceil(),
        _cpixelSize = (pixelFormat.depth + 7) ~/ 8,
        _inflater = RawZLibFilter.inflateFilter();

  final RemoteFrameBufferPixelFormat _pixelFormat;
  final int _bytesPerPixel;
  final int _cpixelSize;
  RawZLibFilter _inflater;

  /// Reset the zlib inflater. Call this when starting a new VNC session.
  void reset() {
    _inflater = RawZLibFilter.inflateFilter();
  }

  /// Decode [zrleData] (length + compressed payload) into raw pixel bytes.
  ByteData decode({
    required final ByteData zrleData,
    required final int width,
    required final int height,
  }) {
    if (zrleData.lengthInBytes < 4) {
      throw const FormatException('ZRLE rectangle is missing length bytes');
    }
    final int declaredLength = zrleData.getUint32(0);
    if (zrleData.lengthInBytes - 4 < declaredLength) {
      throw const FormatException('ZRLE payload shorter than declared length');
    }
    final Uint8List compressedPayload = zrleData.buffer.asUint8List(
      zrleData.offsetInBytes + 4,
      declaredLength,
    );
    if (compressedPayload.isEmpty) {
      return ByteData(width * height * _bytesPerPixel);
    }
    // Use persistent inflater for continuous zlib stream
    final Uint8List decompressed = _inflate(compressedPayload);
    final Uint8List frameBuffer = Uint8List(width * height * _bytesPerPixel);

    int offset = 0;
    for (int tileY = 0; tileY < height; tileY += 64) {
      final int tileHeight = min(64, height - tileY);
      for (int tileX = 0; tileX < width; tileX += 64) {
        final int tileWidth = min(64, width - tileX);
        offset = _decodeTile(
          data: decompressed,
          offset: offset,
          tileX: tileX,
          tileY: tileY,
          tileWidth: tileWidth,
          tileHeight: tileHeight,
          frameBuffer: frameBuffer,
          frameWidth: width,
        );
      }
    }
    if (offset > decompressed.length) {
      throw const FormatException('ZRLE payload shorter than expected');
    }
    return ByteData.sublistView(frameBuffer);
  }

  /// Inflate compressed data using persistent zlib stream.
  Uint8List _inflate(final Uint8List compressed) {
    _inflater.process(compressed, 0, compressed.length);
    final List<int> output = <int>[];
    List<int>? chunk;
    // For continuous zlib stream, we need to flush to get all available data
    // but not finalize the stream (which would be flush: true)
    while ((chunk = _inflater.processed(flush: true)) != null) {
      output.addAll(chunk!);
    }
    return Uint8List.fromList(output);
  }

  int _decodeTile({
    required final Uint8List data,
    required final int offset,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    if (offset >= data.length) {
      throw const FormatException('Unexpected end of ZRLE payload (tile type)');
    }
    final int type = data[offset];
    final int tileOffset = offset + 1;
    if (type == 0) {
      return _decodeRawTile(
        data: data,
        offset: tileOffset,
        tileX: tileX,
        tileY: tileY,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        frameBuffer: frameBuffer,
        frameWidth: frameWidth,
      );
    } else if (type == 1) {
      return _decodeSolidTile(
        data: data,
        offset: tileOffset,
        tileX: tileX,
        tileY: tileY,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        frameBuffer: frameBuffer,
        frameWidth: frameWidth,
      );
    } else if (type >= 2 && type <= 127) {
      return _decodePackedPaletteTile(
        data: data,
        offset: tileOffset,
        paletteSize: type,
        tileX: tileX,
        tileY: tileY,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        frameBuffer: frameBuffer,
        frameWidth: frameWidth,
      );
    } else if (type == 128) {
      return _decodePlainRleTile(
        data: data,
        offset: tileOffset,
        tileX: tileX,
        tileY: tileY,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        frameBuffer: frameBuffer,
        frameWidth: frameWidth,
      );
    } else if (type >= 130 && type <= 255) {
      return _decodePaletteRleTile(
        data: data,
        offset: tileOffset,
        paletteSize: type - 128,
        tileX: tileX,
        tileY: tileY,
        tileWidth: tileWidth,
        tileHeight: tileHeight,
        frameBuffer: frameBuffer,
        frameWidth: frameWidth,
      );
    }
    throw FormatException('Unsupported ZRLE tile type: $type');
  }

  int _decodeRawTile({
    required final Uint8List data,
    required final int offset,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    final int pixels = tileWidth * tileHeight;
    final int bytesNeeded = pixels * _cpixelSize;
    if (offset + bytesNeeded > data.length) {
      throw const FormatException('Raw tile truncated');
    }
    int currentOffset = offset;
    for (int row = 0; row < tileHeight; row++) {
      for (int col = 0; col < tileWidth; col++) {
        final int dstOffset = ((tileY + row) * frameWidth + tileX + col) *
            _bytesPerPixel;
        _writeCpixelToFrame(
          cpixelBytes: data,
          cpixelOffset: currentOffset,
          destination: frameBuffer,
          destinationOffset: dstOffset,
        );
        currentOffset += _cpixelSize;
      }
    }
    return currentOffset;
  }

  int _decodeSolidTile({
    required final Uint8List data,
    required final int offset,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    if (offset + _cpixelSize > data.length) {
      throw const FormatException('Solid tile missing color');
    }
    final Uint8List color = Uint8List(_bytesPerPixel);
    _writeCpixelToFrame(
      cpixelBytes: data,
      cpixelOffset: offset,
      destination: color,
      destinationOffset: 0,
    );
    for (int row = 0; row < tileHeight; row++) {
      for (int col = 0; col < tileWidth; col++) {
        final int dstOffset = ((tileY + row) * frameWidth + tileX + col) *
            _bytesPerPixel;
        frameBuffer.setRange(
          dstOffset,
          dstOffset + _bytesPerPixel,
          color,
        );
      }
    }
    return offset + _cpixelSize;
  }

  int _decodePackedPaletteTile({
    required final Uint8List data,
    required final int offset,
    required final int paletteSize,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    final int paletteBytes = paletteSize * _cpixelSize;
    if (offset + paletteBytes > data.length) {
      throw const FormatException('Packed palette tile missing palette data');
    }
    final List<Uint8List> palette = List<Uint8List>.generate(
      paletteSize,
      (final int index) {
        final Uint8List color = Uint8List(_bytesPerPixel);
        _writeCpixelToFrame(
          cpixelBytes: data,
          cpixelOffset: offset + index * _cpixelSize,
          destination: color,
          destinationOffset: 0,
        );
        return color;
      },
    );
    final int dataOffset = offset + paletteBytes;
    final int bitsPerPixel = paletteSize <= 2
        ? 1
        : paletteSize <= 4
            ? 2
            : paletteSize <= 16
                ? 4
                : 8;
    final int pixelsPerByte = 8 ~/ bitsPerPixel;
    final int bytesPerRow =
        ((tileWidth + pixelsPerByte - 1) ~/ pixelsPerByte).toInt();
    final int packedBytes = bytesPerRow * tileHeight;
    if (dataOffset + packedBytes > data.length) {
      throw const FormatException('Packed palette tile truncated');
    }
    int currentOffset = dataOffset;
    for (int row = 0; row < tileHeight; row++) {
      int shift = 8 - bitsPerPixel;
      int rowStartOffset = currentOffset;
      for (int col = 0; col < tileWidth; col++) {
        if (currentOffset >= data.length) {
          throw const FormatException('Packed palette tile data exhausted');
        }
        final int byteValue = data[currentOffset];
        final int paletteIndex =
            (byteValue >> shift) & ((1 << bitsPerPixel) - 1);
        if (paletteIndex >= palette.length) {
          throw const FormatException('Packed palette index out of range');
        }
        final int dstOffset =
            ((tileY + row) * frameWidth + tileX + col) * _bytesPerPixel;
        frameBuffer.setRange(
          dstOffset,
          dstOffset + _bytesPerPixel,
          palette[paletteIndex],
        );
        shift -= bitsPerPixel;
        if (shift < 0) {
          shift = 8 - bitsPerPixel;
          currentOffset++;
        }
      }
      // Each row is padded to byte boundary
      currentOffset = rowStartOffset + bytesPerRow;
    }
    return currentOffset;
  }

  int _decodePlainRleTile({
    required final Uint8List data,
    required final int offset,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    int currentOffset = offset;
    int row = 0;
    int col = 0;
    final Uint8List colorBuffer = Uint8List(_bytesPerPixel);
    while (row < tileHeight) {
      if (currentOffset + _cpixelSize > data.length) {
        throw const FormatException('Plain RLE tile truncated (color)');
      }
      _writeCpixelToFrame(
        cpixelBytes: data,
        cpixelOffset: currentOffset,
        destination: colorBuffer,
        destinationOffset: 0,
      );
      currentOffset += _cpixelSize;
      final _RunLengthResult run = _readRunLength(
        data: data,
        offset: currentOffset,
        description: 'Plain RLE length',
      );
      currentOffset += run.bytesConsumed;
      int remaining = run.length;
      while (remaining > 0) {
        if (row >= tileHeight) {
          throw const FormatException('Plain RLE overruns tile height');
        }
        final int dstOffset =
            ((tileY + row) * frameWidth + tileX + col) * _bytesPerPixel;
        frameBuffer.setRange(
          dstOffset,
          dstOffset + _bytesPerPixel,
          colorBuffer,
        );
        col++;
        if (col >= tileWidth) {
          col = 0;
          row++;
        }
        remaining--;
      }
    }
    return currentOffset;
  }

  int _decodePaletteRleTile({
    required final Uint8List data,
    required final int offset,
    required final int paletteSize,
    required final int tileX,
    required final int tileY,
    required final int tileWidth,
    required final int tileHeight,
    required final Uint8List frameBuffer,
    required final int frameWidth,
  }) {
    final int paletteBytes = paletteSize * _cpixelSize;
    if (offset + paletteBytes > data.length) {
      throw const FormatException('Palette RLE tile missing palette data');
    }
    final List<Uint8List> palette = List<Uint8List>.generate(
      paletteSize,
      (final int index) {
        final Uint8List color = Uint8List(_bytesPerPixel);
        _writeCpixelToFrame(
          cpixelBytes: data,
          cpixelOffset: offset + index * _cpixelSize,
          destination: color,
          destinationOffset: 0,
        );
        return color;
      },
    );
    int currentOffset = offset + paletteBytes;
    int row = 0;
    int col = 0;
    while (row < tileHeight) {
      if (currentOffset >= data.length) {
        throw const FormatException('Palette RLE tile truncated (entry)');
      }
      final int entry = data[currentOffset++];
      final bool isRun = (entry & 0x80) != 0;
      final int paletteIndex = entry & 0x7F;
      if (paletteIndex >= palette.length) {
        throw const FormatException('Palette RLE index out of range');
      }
      int runLength = 1;
      if (isRun) {
        final _RunLengthResult run = _readRunLength(
          data: data,
          offset: currentOffset,
          description: 'Palette RLE length',
        );
        runLength = run.length;
        currentOffset += run.bytesConsumed;
      }
      int remaining = runLength;
      while (remaining > 0) {
        if (row >= tileHeight) {
          throw const FormatException('Palette RLE overruns tile height');
        }
        final int dstOffset =
            ((tileY + row) * frameWidth + tileX + col) * _bytesPerPixel;
        frameBuffer.setRange(
          dstOffset,
          dstOffset + _bytesPerPixel,
          palette[paletteIndex],
        );
        col++;
        if (col >= tileWidth) {
          col = 0;
          row++;
        }
        remaining--;
      }
    }
    return currentOffset;
  }

  _RunLengthResult _readRunLength({
    required final Uint8List data,
    required final int offset,
    required final String description,
  }) {
    if (offset >= data.length) {
      throw FormatException('$description truncated');
    }
    int length = 1;
    int consumed = 0;
    int currentOffset = offset;
    while (currentOffset < data.length && data[currentOffset] == 0xFF) {
      length += 255;
      currentOffset++;
      consumed++;
      if (currentOffset >= data.length) {
        throw FormatException('$description truncated');
      }
    }
    length += data[currentOffset];
    consumed++;
    return _RunLengthResult(length: length, bytesConsumed: consumed);
  }

  void _writeCpixelToFrame({
    required final Uint8List cpixelBytes,
    required final int cpixelOffset,
    required final Uint8List destination,
    required final int destinationOffset,
  }) {
    if (_pixelFormat.bigEndian) {
      final int padding = _bytesPerPixel - _cpixelSize;
      // Set alpha channel to 255 (fully opaque) for ARGB format
      for (int i = 0; i < padding; i++) {
        destination[destinationOffset + i] = 0xFF;
      }
      for (int i = 0; i < _cpixelSize; i++) {
        destination[destinationOffset + padding + i] =
            cpixelBytes[cpixelOffset + i];
      }
      return;
    }
    for (int i = 0; i < _cpixelSize; i++) {
      destination[destinationOffset + i] =
          cpixelBytes[cpixelOffset + i];
    }
    // Set alpha channel to 255 (fully opaque) for BGRA format
    for (int i = _cpixelSize; i < _bytesPerPixel; i++) {
      destination[destinationOffset + i] = 0xFF;
    }
  }
}

class _RunLengthResult {
  const _RunLengthResult({
    required this.length,
    required this.bytesConsumed,
  });

  final int length;
  final int bytesConsumed;
}

