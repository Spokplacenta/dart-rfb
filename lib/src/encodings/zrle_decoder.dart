import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';

/// Decoder for ZRLE rectangles (see RFC 6143 §7.7.6.9).
///
/// Supports the 8, 16 and 32 bpp true colour formats of [PixelConverter]. The
/// output is always opaque BGRA8888, 4 bytes per pixel, whatever the
/// negotiated format.
///
/// IMPORTANT: ZRLE uses a continuous zlib stream across all rectangles in a
/// session. The [_inflater] must be reused for all decode() calls. Call
/// [reset()] only when starting a new VNC session.
class ZrleDecoder {
  ZrleDecoder({
    required final RemoteFrameBufferPixelFormat pixelFormat,
  }) : this.withConverter(
          converter: PixelConverter(pixelFormat: pixelFormat),
        );

  /// A decoder sharing [converter] (and its lookup table) with the caller.
  ZrleDecoder.withConverter({required final PixelConverter converter})
      : _converter = converter,
        _cpixelSize = cpixelSize(converter.pixelFormat),
        _inflater = RawZLibFilter.inflateFilter();

  final PixelConverter _converter;
  final int _cpixelSize;
  RawZLibFilter _inflater;

  /// Palette of the current tile, reused from tile to tile.
  final Uint32List _palette = Uint32List(128);

  /// Size of a CPIXEL in [pixelFormat].
  ///
  /// RFC 6143 §7.7.6: a CPIXEL is 3 bytes for a true colour 32 bpp format
  /// whose colours fit in 24 bits, otherwise a full pixel (1 or 2 bytes at
  /// 8 or 16 bpp).
  static int cpixelSize(final RemoteFrameBufferPixelFormat pixelFormat) =>
      pixelFormat.trueColor &&
              pixelFormat.bitsPerPixel == 32 &&
              pixelFormat.depth <= 24
          ? 3
          : pixelFormat.bitsPerPixel ~/ 8;

  /// Reset the zlib inflater. Call this when starting a new VNC session.
  void reset() {
    _inflater = RawZLibFilter.inflateFilter();
  }

  /// Decode [zrleData] (length + compressed payload) into opaque BGRA8888
  /// pixel bytes.
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
    final Uint32List frameBuffer = Uint32List(width * height);
    if (compressedPayload.isEmpty) {
      return ByteData.sublistView(frameBuffer);
    }
    // Use persistent inflater for continuous zlib stream
    final Uint8List decompressed = _inflate(compressedPayload);

    int offset = 0;
    for (int tileY = 0; tileY < height; tileY += 64) {
      final int tileHeight = min(64, height - tileY);
      for (int tileX = 0; tileX < width; tileX += 64) {
        final int tileWidth = min(64, width - tileX);
        offset = _decodeTile(
          data: decompressed,
          offset: offset,
          tile: _Tile(
            frameBuffer: frameBuffer,
            frameWidth: width,
            height: tileHeight,
            width: tileWidth,
            x: tileX,
            y: tileY,
          ),
        );
      }
    }
    return ByteData.sublistView(frameBuffer);
  }

  /// Inflate compressed data using persistent zlib stream.
  Uint8List _inflate(final Uint8List compressed) {
    _inflater.process(compressed, 0, compressed.length);
    final BytesBuilder output = BytesBuilder(copy: false);
    List<int>? chunk;
    // For continuous zlib stream, we need to flush to get all available data
    // but not finalize the stream (which would be flush: true)
    while ((chunk = _inflater.processed(flush: true)) != null) {
      output.add(chunk!);
    }
    return output.takeBytes();
  }

  /// Reads the CPIXEL at [offset] as an opaque BGRA8888 value.
  int _readCpixel(final Uint8List data, final int offset) =>
      _converter.convert(_converter.readPixel(data, offset, _cpixelSize));

  int _readPalette({
    required final Uint8List data,
    required final int offset,
    required final int paletteSize,
    required final String description,
  }) {
    final int paletteBytes = paletteSize * _cpixelSize;
    if (offset + paletteBytes > data.length) {
      throw FormatException('$description tile missing palette data');
    }
    for (int i = 0; i < paletteSize; i++) {
      _palette[i] = _readCpixel(data, offset + i * _cpixelSize);
    }
    return offset + paletteBytes;
  }

  int _decodeTile({
    required final Uint8List data,
    required final int offset,
    required final _Tile tile,
  }) {
    if (offset >= data.length) {
      throw const FormatException('Unexpected end of ZRLE payload (tile type)');
    }
    final int type = data[offset];
    final int tileOffset = offset + 1;
    if (type == 0) {
      return _decodeRawTile(data: data, offset: tileOffset, tile: tile);
    } else if (type == 1) {
      return _decodeSolidTile(data: data, offset: tileOffset, tile: tile);
    } else if (type >= 2 && type <= 16) {
      return _decodePackedPaletteTile(
        data: data,
        offset: tileOffset,
        paletteSize: type,
        tile: tile,
      );
    } else if (type == 128) {
      return _decodePlainRleTile(data: data, offset: tileOffset, tile: tile);
    } else if (type >= 130 && type <= 255) {
      return _decodePaletteRleTile(
        data: data,
        offset: tileOffset,
        paletteSize: type - 128,
        tile: tile,
      );
    }
    throw FormatException('Unsupported ZRLE tile type: $type');
  }

  int _decodeRawTile({
    required final Uint8List data,
    required final int offset,
    required final _Tile tile,
  }) {
    if (offset + tile.width * tile.height * _cpixelSize > data.length) {
      throw const FormatException('Raw tile truncated');
    }
    int currentOffset = offset;
    for (int row = 0; row < tile.height; row++) {
      int destination = tile.rowStart(row);
      for (int col = 0; col < tile.width; col++) {
        tile.frameBuffer[destination++] = _readCpixel(data, currentOffset);
        currentOffset += _cpixelSize;
      }
    }
    return currentOffset;
  }

  int _decodeSolidTile({
    required final Uint8List data,
    required final int offset,
    required final _Tile tile,
  }) {
    if (offset + _cpixelSize > data.length) {
      throw const FormatException('Solid tile missing color');
    }
    final int color = _readCpixel(data, offset);
    for (int row = 0; row < tile.height; row++) {
      final int start = tile.rowStart(row);
      tile.frameBuffer.fillRange(start, start + tile.width, color);
    }
    return offset + _cpixelSize;
  }

  int _decodePackedPaletteTile({
    required final Uint8List data,
    required final int offset,
    required final int paletteSize,
    required final _Tile tile,
  }) {
    final int dataOffset = _readPalette(
      data: data,
      offset: offset,
      paletteSize: paletteSize,
      description: 'Packed palette',
    );
    final int bitsPerIndex = paletteSize <= 2
        ? 1
        : paletteSize <= 4
            ? 2
            : 4;
    final int mask = (1 << bitsPerIndex) - 1;
    final int bytesPerRow = (tile.width * bitsPerIndex + 7) ~/ 8;
    if (dataOffset + bytesPerRow * tile.height > data.length) {
      throw const FormatException('Packed palette tile truncated');
    }
    int rowOffset = dataOffset;
    for (int row = 0; row < tile.height; row++) {
      int destination = tile.rowStart(row);
      int byteOffset = rowOffset;
      int shift = 8 - bitsPerIndex;
      for (int col = 0; col < tile.width; col++) {
        final int paletteIndex = (data[byteOffset] >> shift) & mask;
        if (paletteIndex >= paletteSize) {
          throw const FormatException('Packed palette index out of range');
        }
        tile.frameBuffer[destination++] = _palette[paletteIndex];
        shift -= bitsPerIndex;
        if (shift < 0) {
          shift = 8 - bitsPerIndex;
          byteOffset++;
        }
      }
      // Each row is padded to byte boundary
      rowOffset += bytesPerRow;
    }
    return rowOffset;
  }

  int _decodePlainRleTile({
    required final Uint8List data,
    required final int offset,
    required final _Tile tile,
  }) {
    int currentOffset = offset;
    int position = 0;
    final int pixelCount = tile.width * tile.height;
    while (position < pixelCount) {
      if (currentOffset + _cpixelSize > data.length) {
        throw const FormatException('Plain RLE tile truncated (color)');
      }
      final int color = _readCpixel(data, currentOffset);
      currentOffset += _cpixelSize;
      final _RunLengthResult run = _readRunLength(
        data: data,
        offset: currentOffset,
        description: 'Plain RLE length',
      );
      currentOffset += run.bytesConsumed;
      if (position + run.length > pixelCount) {
        throw const FormatException('Plain RLE overruns tile height');
      }
      tile.fillRun(position, run.length, color);
      position += run.length;
    }
    return currentOffset;
  }

  int _decodePaletteRleTile({
    required final Uint8List data,
    required final int offset,
    required final int paletteSize,
    required final _Tile tile,
  }) {
    int currentOffset = _readPalette(
      data: data,
      offset: offset,
      paletteSize: paletteSize,
      description: 'Palette RLE',
    );
    int position = 0;
    final int pixelCount = tile.width * tile.height;
    while (position < pixelCount) {
      if (currentOffset >= data.length) {
        throw const FormatException('Palette RLE tile truncated (entry)');
      }
      final int entry = data[currentOffset++];
      final int paletteIndex = entry & 0x7F;
      if (paletteIndex >= paletteSize) {
        throw const FormatException('Palette RLE index out of range');
      }
      int runLength = 1;
      if ((entry & 0x80) != 0) {
        final _RunLengthResult run = _readRunLength(
          data: data,
          offset: currentOffset,
          description: 'Palette RLE length',
        );
        runLength = run.length;
        currentOffset += run.bytesConsumed;
      }
      if (position + runLength > pixelCount) {
        throw const FormatException('Palette RLE overruns tile height');
      }
      tile.fillRun(position, runLength, _palette[paletteIndex]);
      position += runLength;
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
}

/// A tile of the rectangle being decoded, in [frameBuffer].
class _Tile {
  const _Tile({
    required this.frameBuffer,
    required this.frameWidth,
    required this.height,
    required this.width,
    required this.x,
    required this.y,
  });

  final Uint32List frameBuffer;
  final int frameWidth;
  final int height;
  final int width;
  final int x;
  final int y;

  /// Index in [frameBuffer] of the first pixel of [row].
  int rowStart(final int row) => (y + row) * frameWidth + x;

  /// Fills [length] pixels with [color], from pixel [position] of the tile in
  /// row-major order, across rows.
  void fillRun(final int position, final int length, final int color) {
    int row = position ~/ width;
    int col = position % width;
    int remaining = length;
    while (remaining > 0) {
      final int count = min(remaining, width - col);
      final int start = rowStart(row) + col;
      frameBuffer.fillRange(start, start + count, color);
      remaining -= count;
      col = 0;
      row++;
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
