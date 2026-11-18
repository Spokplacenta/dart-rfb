import 'dart:typed_data';

import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/encodings/hextile_decoder.dart';
import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/encodings/zlib_decoder.dart';
import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:dart_rfb/src/protocol/frame_buffer_update_message.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';

class RemoteFrameBufferRectangleConverter {
  RemoteFrameBufferRectangleConverter();

  final Logger _logger = Logger('RemoteFrameBufferRectangleConverter');

  /// Converts [rectangle] into a rectangle the caller can draw: ZRLE, ZLib
  /// and Hextile are decoded with [zrleDecoder], [zlibDecoder] and
  /// [hextileDecoder], and Raw pixels are converted to opaque BGRA8888 with
  /// [pixelConverter] (left untouched without one). Decoded rectangles are
  /// delivered as Raw.
  RemoteFrameBufferClientUpdateRectangle convert({
    required final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
    required final Option<ZrleDecoder> zrleDecoder,
    final Option<HextileDecoder> hextileDecoder = const None<HextileDecoder>(),
    final Option<PixelConverter> pixelConverter = const None<PixelConverter>(),
    final Option<ZlibDecoder> zlibDecoder = const None<ZlibDecoder>(),
  }) =>
      rectangle.encodingType.map(
        copyRect: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: rectangle.pixelData,
          encodingType: rectangle.encodingType,
        ),
        // The client decodes cursors with a CursorDecoder, out of the
        // framebuffer rectangles.
        cursor: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: rectangle.pixelData,
          encodingType: rectangle.encodingType,
        ),
        hextile: (final _) => _decode(
          rectangle: rectangle,
          name: 'Hextile',
          decode: hextileDecoder.map(
            (final HextileDecoder decoder) => () => decoder.decode(
                  data: rectangle.pixelData,
                  width: rectangle.width,
                  height: rectangle.height,
                ),
          ),
        ),
        raw: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: pixelConverter.match(
            () => rectangle.pixelData,
            (final PixelConverter converter) => converter.convertRaw(
              pixelData: rectangle.pixelData,
              width: rectangle.width,
              height: rectangle.height,
            ),
          ),
          encodingType: rectangle.encodingType,
        ),
        zlib: (final _) => _decode(
          rectangle: rectangle,
          name: 'ZLib',
          decode: zlibDecoder.map(
            (final ZlibDecoder decoder) => () => decoder.decode(
                  compressed: rectangle.pixelData,
                  width: rectangle.width,
                  height: rectangle.height,
                ),
          ),
        ),
        zrle: (final _) => _handleZrle(
          rectangle: rectangle,
          decoder: zrleDecoder,
        ),
        unsupported: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: rectangle.pixelData,
          encodingType: rectangle.encodingType,
        ),
      );

  RemoteFrameBufferClientUpdateRectangle _handleZrle({
    required final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
    required final Option<ZrleDecoder> decoder,
  }) =>
      decoder.match(
        () {
          _logger.warning(
            'Received ZRLE rectangle but decoder is not initialised',
          );
          return _buildRectangle(
            rectangle: rectangle,
            byteData: rectangle.pixelData,
            encodingType: rectangle.encodingType,
          );
        },
        (final ZrleDecoder decoder) {
          try {
            final ByteData decoded = decoder.decode(
              zrleData: rectangle.pixelData,
              width: rectangle.width,
              height: rectangle.height,
            );
            return _buildRectangle(
              rectangle: rectangle,
              byteData: decoded,
              encodingType: const RemoteFrameBufferEncodingType.raw(),
            );
          } on FormatException catch (error, stackTrace) {
            _logger
              ..warning(
                'Failed to decode ZRLE rectangle: $error',
              )
              ..fine(stackTrace);
            return _buildRectangle(
              rectangle: rectangle,
              byteData: rectangle.pixelData,
              encodingType: rectangle.encodingType,
            );
          }
        },
      );

  /// Decodes [rectangle] with [decode] into a Raw rectangle, or leaves it
  /// undecoded (and logs why) without a decoder or on bad data.
  RemoteFrameBufferClientUpdateRectangle _decode({
    required final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
    required final String name,
    required final Option<ByteData Function()> decode,
  }) =>
      decode.match(
        () {
          _logger.warning(
            'Received $name rectangle but decoder is not initialised',
          );
          return _buildRectangle(
            rectangle: rectangle,
            byteData: rectangle.pixelData,
            encodingType: rectangle.encodingType,
          );
        },
        (final ByteData Function() decode) {
          try {
            return _buildRectangle(
              rectangle: rectangle,
              byteData: decode(),
              encodingType: const RemoteFrameBufferEncodingType.raw(),
            );
          } on FormatException catch (error, stackTrace) {
            _logger
              ..warning('Failed to decode $name rectangle: $error')
              ..fine(stackTrace);
            return _buildRectangle(
              rectangle: rectangle,
              byteData: rectangle.pixelData,
              encodingType: rectangle.encodingType,
            );
          }
        },
      );

  RemoteFrameBufferClientUpdateRectangle _buildRectangle({
    required final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
    required final ByteData byteData,
    required final RemoteFrameBufferEncodingType encodingType,
  }) =>
      RemoteFrameBufferClientUpdateRectangle(
        byteData: byteData,
        encodingType: encodingType,
        height: rectangle.height,
        width: rectangle.width,
        x: rectangle.x,
        y: rectangle.y,
      );
}
