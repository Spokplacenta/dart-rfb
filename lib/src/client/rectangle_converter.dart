import 'dart:typed_data';

import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:dart_rfb/src/protocol/frame_buffer_update_message.dart';
import 'package:logging/logging.dart';

class RemoteFrameBufferRectangleConverter {
  RemoteFrameBufferRectangleConverter();

  final Logger _logger = Logger('RemoteFrameBufferRectangleConverter');

  RemoteFrameBufferClientUpdateRectangle convert({
    required final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
    final ZrleDecoder? zrleDecoder,
  }) =>
      rectangle.encodingType.map(
        copyRect: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: rectangle.pixelData,
          encodingType: rectangle.encodingType,
        ),
        raw: (final _) => _buildRectangle(
          rectangle: rectangle,
          byteData: rectangle.pixelData,
          encodingType: rectangle.encodingType,
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
    required final ZrleDecoder? decoder,
  }) {
    if (decoder == null) {
      _logger.warning(
        'Received ZRLE rectangle but decoder is not initialised',
      );
      return _buildRectangle(
        rectangle: rectangle,
        byteData: rectangle.pixelData,
        encodingType: rectangle.encodingType,
      );
    }
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
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to decode ZRLE rectangle: $error',
      );
      _logger.fine(stackTrace);
      return _buildRectangle(
        rectangle: rectangle,
        byteData: rectangle.pixelData,
        encodingType: rectangle.encodingType,
      );
    }
  }

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

