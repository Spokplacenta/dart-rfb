import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'encoding_type.freezed.dart';

/// Encoding types as defined by RFC 6143.
///
/// See: https://www.rfc-editor.org/rfc/rfc6143.html#section-7.7
@freezed
class RemoteFrameBufferEncodingType with _$RemoteFrameBufferEncodingType {
  const factory RemoteFrameBufferEncodingType.copyRect() =
      RemoteFrameBufferEncodingTypeCopyRect;

  /// The Cursor pseudo-encoding: the server sends the cursor shape instead of
  /// drawing it into the framebuffer.
  ///
  /// See: https://www.rfc-editor.org/rfc/rfc6143.html#section-7.8.1
  const factory RemoteFrameBufferEncodingType.cursor() =
      RemoteFrameBufferEncodingTypeCursor;

  /// Hextile: 16x16 tiles of solid backgrounds and subrectangles.
  ///
  /// See: https://www.rfc-editor.org/rfc/rfc6143.html#section-7.7.4
  const factory RemoteFrameBufferEncodingType.hextile() =
      RemoteFrameBufferEncodingTypeHextile;
  const factory RemoteFrameBufferEncodingType.raw() =
      RemoteFrameBufferEncodingTypeRaw;

  /// ZLib: Raw pixels compressed with one zlib stream for the whole
  /// connection.
  ///
  /// See: https://github.com/rfbproto/rfbproto/blob/master/rfbproto.rst#zlib-encoding
  const factory RemoteFrameBufferEncodingType.zlib() =
      RemoteFrameBufferEncodingTypeZlib;
  const factory RemoteFrameBufferEncodingType.zrle() =
      RemoteFrameBufferEncodingTypeZrle;
  const factory RemoteFrameBufferEncodingType.unsupported({
    required final ByteData bytes,
  }) = RemoteFrameBufferEncodingTypeUnsupported;

  /// Parse [bytes].
  factory RemoteFrameBufferEncodingType.fromBytes({
    required final ByteData bytes,
  }) {
    switch (bytes.getInt32(0)) {
      case 0:
        return const RemoteFrameBufferEncodingType.raw();
      case 1:
        return const RemoteFrameBufferEncodingType.copyRect();
      case 5:
        return const RemoteFrameBufferEncodingType.hextile();
      case 6:
        return const RemoteFrameBufferEncodingType.zlib();
      case 16:
        return const RemoteFrameBufferEncodingType.zrle();
      case -239:
        return const RemoteFrameBufferEncodingType.cursor();
      default:
        return RemoteFrameBufferEncodingType.unsupported(bytes: bytes);
    }
  }

  /// Generate byte representation of this encoding type.
  ByteData toBytes() => ByteData(4)
    ..setInt32(
      0,
      map(
        copyRect: (final _) => 1,
        cursor: (final _) => -239,
        hextile: (final _) => 5,
        raw: (final _) => 0,
        zlib: (final _) => 6,
        zrle: (final _) => 16,
        unsupported: (final _) => -1,
      ),
    );

  const RemoteFrameBufferEncodingType._();
}
