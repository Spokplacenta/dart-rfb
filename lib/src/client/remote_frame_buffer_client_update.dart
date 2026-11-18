import 'dart:typed_data';

import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_frame_buffer_client_update.freezed.dart';

/// Holds the configuration of the currently active framebuffer.
@freezed
class RemoteFrameBufferClientFrameBufferConfig
    with _$RemoteFrameBufferClientFrameBufferConfig {
  const factory RemoteFrameBufferClientFrameBufferConfig({
    required final int height,
    required final int width,
  }) = _RemoteFrameBufferClientFrameBufferConfig;
}

/// Holds all data that is associated with this framebuffer update.
@freezed
class RemoteFrameBufferClientUpdate with _$RemoteFrameBufferClientUpdate {
  const factory RemoteFrameBufferClientUpdate({
    /// The new cursor shape, when this update carries one (Cursor
    /// pseudo-encoding, see `RemoteFrameBufferClient(localCursor:)`). The
    /// cursor is not part of the framebuffer: draw it yourself at the pointer.
    @Default(None<RemoteFrameBufferClientCursor>())
    final Option<RemoteFrameBufferClientCursor> cursor,

    /// The list of [RemoteFrameBufferClientUpdateRectangle]s that make this update.
    /// Cursor rectangles are not in this list, see [cursor].
    required final Iterable<RemoteFrameBufferClientUpdateRectangle> rectangles,
  }) = _RemoteFrameBufferClientUpdate;
}

/// A cursor shape sent by the server (Cursor pseudo-encoding).
@freezed
class RemoteFrameBufferClientCursor with _$RemoteFrameBufferClientCursor {
  const factory RemoteFrameBufferClientCursor({
    /// The height in pixels, 0 for an invisible cursor.
    required final int height,

    /// The x offset of the hotspot, the point of the cursor at the pointer.
    required final int hotspotX,

    /// The y offset of the hotspot.
    required final int hotspotY,

    /// [width] x [height] BGRA8888 pixels. The alpha comes from the cursor
    /// bitmask: 255 where the cursor is drawn, 0 elsewhere, and the colour of
    /// transparent pixels is 0, so the pixels are both premultiplied and
    /// straight.
    required final ByteData pixels,

    /// The width in pixels, 0 for an invisible cursor.
    required final int width,
  }) = _RemoteFrameBufferClientCursor;

  const RemoteFrameBufferClientCursor._();

  /// Whether the server wants a visible cursor: a 0x0 cursor hides it.
  bool get isVisible => width > 0 && height > 0;
}

/// Contains all data that is relevant for an updated rectangle.
@freezed
class RemoteFrameBufferClientUpdateRectangle
    with _$RemoteFrameBufferClientUpdateRectangle {
  const factory RemoteFrameBufferClientUpdateRectangle({
    /// The [ByteData] that holds the pixel data of this rectangle.
    required final ByteData byteData,

    /// The encoding used to interpret the bytes in [byteData].
    required final RemoteFrameBufferEncodingType encodingType,

    /// The height in pixels.
    required final int height,

    /// The width in pixels.
    required final int width,

    /// The starting x offset of this rectangle.
    required final int x,

    /// The starting y offset of this rectangle.
    required final int y,
  }) = _RemoteFrameBufferClientUpdateRectangle;
}
