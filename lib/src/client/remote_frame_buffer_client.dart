import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dart_des/dart_des.dart';
import 'package:dart_rfb/src/client/config.dart';
import 'package:dart_rfb/src/client/rectangle_converter.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_key_event.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_pointer_event.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_read_message.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_update.dart';
import 'package:dart_rfb/src/client/socket_writer.dart';
import 'package:dart_rfb/src/constants.dart';
import 'package:dart_rfb/src/encodings/cursor_decoder.dart';
import 'package:dart_rfb/src/encodings/hextile_decoder.dart';
import 'package:dart_rfb/src/encodings/pixel_converter.dart';
import 'package:dart_rfb/src/encodings/zlib_decoder.dart';
import 'package:dart_rfb/src/encodings/zrle_decoder.dart';
import 'package:dart_rfb/src/extensions/byte_data_extensions.dart';
import 'package:dart_rfb/src/extensions/int_extensions.dart';
import 'package:dart_rfb/src/extensions/raw_socket_extensions.dart';
import 'package:dart_rfb/src/protocol/client_cut_text_message.dart';
import 'package:dart_rfb/src/protocol/client_init_message.dart';
import 'package:dart_rfb/src/protocol/encoding_type.dart';
import 'package:dart_rfb/src/protocol/frame_buffer_update_message.dart';
import 'package:dart_rfb/src/protocol/frame_buffer_update_request_message.dart';
import 'package:dart_rfb/src/protocol/key_event_message.dart';
import 'package:dart_rfb/src/protocol/pixel_format.dart';
import 'package:dart_rfb/src/protocol/pointer_event_message.dart';
import 'package:dart_rfb/src/protocol/protocol_version_handshake_message.dart';
import 'package:dart_rfb/src/protocol/security_handshake_message.dart';
import 'package:dart_rfb/src/protocol/security_result_handshake_message.dart';
import 'package:dart_rfb/src/protocol/security_type.dart';
import 'package:dart_rfb/src/protocol/server_cut_text_message.dart';
import 'package:dart_rfb/src/protocol/server_init_message.dart';
import 'package:dart_rfb/src/protocol/set_encodings_message.dart';
import 'package:dart_rfb/src/protocol/set_pixel_format_message.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// A client that implements communication according to
/// The Remote Framebuffer Protocol, aka RFC 6143, aka VNC).
class RemoteFrameBufferClient {
  static final Logger logger = Logger('RemoteFrameBufferClient');

  Option<Config> _config = none();

  Option<StreamSubscription<RemoteFrameBufferClientReadMessage>>
      _incomingMessagesSubscription = none();

  Option<CursorDecoder> _cursorDecoder = none();

  Option<HextileDecoder> _hextileDecoder = none();

  /// The encodings announced, in order, Raw last at the latest.
  final List<RemoteFrameBufferEncodingType> _encodings;

  final bool _localCursor;

  Option<String> _password = none();

  final bool _pipelineUpdateRequests;

  final RemoteFrameBufferPixelFormat _pixelFormat;

  Option<PixelConverter> _pixelConverter = none();

  bool _readLoopRunning = false;

  Option<RemoteFrameBufferProtocolVersion> _selectedProtocolVersion = none();

  Option<RemoteFrameBufferSecurityType> _selectedSecurityType = none();

  Option<RawSocket> _socket = none();

  Option<SocketWriter> _writer = none();

  /// ZLib's own zlib stream, kept for the whole connection.
  Option<ZlibDecoder> _zlibDecoder = none();

  Option<ZrleDecoder> _zrleDecoder = none();

  final RemoteFrameBufferRectangleConverter _rectangleConverter =
      RemoteFrameBufferRectangleConverter();

  final StreamController<String> _serverClipBoardStreamController =
      StreamController<String>();

  final StreamController<RemoteFrameBufferClientUpdate>
      _updateStreamController =
      StreamController<RemoteFrameBufferClientUpdate>.broadcast();

  /// Creates a client.
  ///
  /// With [pipelineUpdateRequests] (the default), the client sends the next
  /// incremental [requestUpdate] itself as soon as it reads the header of a
  /// framebuffer update, while the server is still sending the rectangles.
  /// One request is thus always pending on the server, which no longer waits
  /// for the client to finish rendering: call [requestUpdate] once to start.
  /// Set it to `false` to send every request yourself.
  ///
  /// [pixelFormat] is the format asked to the server with SetPixelFormat:
  /// [RemoteFrameBufferPixelFormat.rgb565] (the default),
  /// [RemoteFrameBufferPixelFormat.bgr233] or
  /// [RemoteFrameBufferPixelFormat.bgra8888]. A smaller format means less data
  /// on slow links. Whatever the format, updates are delivered as opaque
  /// BGRA8888 pixels. Only true colour formats of 8, 16 or 32 bits per pixel
  /// are supported.
  ///
  /// With [localCursor], the client announces the Cursor pseudo-encoding: a
  /// server that supports it stops drawing the cursor into the framebuffer
  /// and sends its shape instead, in [RemoteFrameBufferClientUpdate.cursor].
  /// The caller then draws it at the local pointer, which follows the mouse
  /// without waiting for the server. Off by default: a caller that does not
  /// draw the cursor would otherwise lose it.
  ///
  /// [encodings] are the encodings announced to the server, in order of
  /// preference, among [supportedEncodings]: servers use the first one they
  /// know. The default, [defaultEncodings], is ZRLE, ZLib, Hextile, CopyRect,
  /// Raw. Raw is added at the end when missing, so that every server has an
  /// encoding to fall back on. See [normalizeEncodings] for what is
  /// rejected.
  RemoteFrameBufferClient({
    final List<RemoteFrameBufferEncodingType> encodings = defaultEncodings,
    final bool localCursor = false,
    final bool pipelineUpdateRequests = true,
    final RemoteFrameBufferPixelFormat pixelFormat =
        RemoteFrameBufferPixelFormat.rgb565,
  })  : _encodings = normalizeEncodings(encodings),
        _localCursor = localCursor,
        _pipelineUpdateRequests = pipelineUpdateRequests,
        _pixelFormat = pixelFormat {
    // Fail now rather than after the handshake.
    PixelConverter(pixelFormat: pixelFormat);
  }

  /// The real encodings this client decodes, ZRLE first: the choices for
  /// [RemoteFrameBufferClient.new]'s `encodings`.
  static const List<RemoteFrameBufferEncodingType> supportedEncodings =
      <RemoteFrameBufferEncodingType>[
    RemoteFrameBufferEncodingType.zrle(),
    RemoteFrameBufferEncodingType.zlib(),
    RemoteFrameBufferEncodingType.hextile(),
    RemoteFrameBufferEncodingType.copyRect(),
    RemoteFrameBufferEncodingType.raw(),
  ];

  /// The encodings announced by default: servers use the first one of this
  /// list they know, ZRLE where available (x11vnc), else ZLib, else Hextile,
  /// rather than Raw (an HMI without ZRLE sends 768 KB per 800x480 screen in
  /// Raw, 29 KB in ZLib).
  static const List<RemoteFrameBufferEncodingType> defaultEncodings =
      supportedEncodings;

  /// Checks [encodings] and returns the list announced to the server: the
  /// same encodings in the same order, with Raw added at the end when
  /// missing.
  ///
  /// Throws an [ArgumentError] for an empty list, a repeated encoding, or an
  /// encoding that is not in [supportedEncodings] (a pseudo-encoding such as
  /// Cursor, which [localCursor] controls, or one this client cannot decode).
  static List<RemoteFrameBufferEncodingType> normalizeEncodings(
    final List<RemoteFrameBufferEncodingType> encodings,
  ) {
    if (encodings.isEmpty) {
      throw ArgumentError.value(
        encodings,
        'encodings',
        'At least one encoding is needed',
      );
    }
    for (final RemoteFrameBufferEncodingType encoding in encodings) {
      if (!supportedEncodings.contains(encoding)) {
        throw ArgumentError.value(
          encodings,
          'encodings',
          'Unsupported encoding $encoding (supported: $supportedEncodings)',
        );
      }
    }
    if (encodings.toSet().length != encodings.length) {
      throw ArgumentError.value(
        encodings,
        'encodings',
        'An encoding appears more than once',
      );
    }
    return List<RemoteFrameBufferEncodingType>.unmodifiable(
      <RemoteFrameBufferEncodingType>[
        ...encodings,
        if (!encodings.contains(const RemoteFrameBufferEncodingType.raw()))
          const RemoteFrameBufferEncodingType.raw(),
      ],
    );
  }

  /// The config used by the underlying session.
  Option<Config> get config => _config;

  /// The real encodings announced, in order, see
  /// [RemoteFrameBufferClient.new].
  List<RemoteFrameBufferEncodingType> get encodings => _encodings;

  /// Whether the Cursor pseudo-encoding is announced, see
  /// [RemoteFrameBufferClient.new].
  bool get localCursor => _localCursor;

  /// Whether update requests are pipelined, see [RemoteFrameBufferClient.new].
  bool get pipelineUpdateRequests => _pipelineUpdateRequests;

  /// The underlying socket, once connected.
  @visibleForTesting
  Option<RawSocket> get socket => _socket;

  /// Start the reading loop that reads incoming protocol messages.
  /// You can then call [handleIncomingMessages] to let the package handle
  /// incoming messages or just listen to the returned [Stream] diretly to
  /// handle incoming messages yourself.
  Stream<RemoteFrameBufferClientReadMessage> get incomingMessages async* {
    assert(!_readLoopRunning);
    yield* _socket.match(
      () => throw Exception('Socket not available'),
      (final RawSocket socket) async* {
        final Config config =
            _config.getOrElse(() => throw Exception('Config not available'));
        _readLoopRunning = true;
        while (_readLoopRunning) {
          // One turn of the event loop per message: when the next message is
          // always there already, no read waits, and the isolate would never
          // handle its other events (e.g. the pointer events to send).
          await Future<void>.delayed(Duration.zero);
          final int messageType = (await socket
                  .readSync(
                    length: 1,
                    readWaitDuration: some(Constants.socketReadWaitDuration),
                  )
                  .run())
              .getUint8(0);
          logger.log(Level.INFO, '< messageType: $messageType');
          switch (messageType) {
            case 0:
              // read and ignore padding
              await socket.readSync(length: 1).run();
              if (_pipelineUpdateRequests) {
                // Ask for the next update now rather than after rendering, so
                // the server never waits for a round trip.
                requestUpdate();
              }
              yield (await RemoteFrameBufferFrameBufferUpdateMessage
                          .readFromSocket(config: config, socket: socket)
                      .run())
                  .match(
                (final Object error) => throw Exception(
                  'Error reading and handling update message: $error',
                ),
                (
                  final RemoteFrameBufferFrameBufferUpdateMessage updateMessage,
                ) {
                  logger.info(
                    '< update rectangles: ${updateMessage.rectangles.groupListsBy((final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle) => rectangle.encodingType).mapValue((final List<RemoteFrameBufferFrameBufferUpdateMessageRectangle> list) => list.length)}',
                  );
                  return RemoteFrameBufferClientReadMessage.frameBufferUpdate(
                    message: updateMessage,
                  );
                },
              );
              break;
            case 1: // SetColorMapEntries
              final int numberOfColors =
                  (await socket.readSync(length: 5).run()).getUint16(3);
              await socket.readSync(length: numberOfColors * 6).run();
              yield const RemoteFrameBufferClientReadMessage
                  .setColorMapEntries();
              break;
            case 2: // Bell
              // no data, just ignore for now
              yield const RemoteFrameBufferClientReadMessage.bell();
              break;
            case 3: // ServerCutText
              final RemoteFrameBufferServerCutTextMessage message =
                  (await RemoteFrameBufferServerCutTextMessage.readFromSocket(
                socket: socket,
              ).run())
                      .getOrElse(
                (final Object error) => throw Exception(
                  'Error reading server cut text: $error',
                ),
              );
              logger.info('< $message');
              yield RemoteFrameBufferClientReadMessage.serverCutTextMessage(
                message: message,
              );
              // _serverClipBoardStreamController.add(message.text);
              break;
            default:
              throw Exception('Receive unsupported message type: $messageType');
          }
        }
      },
    );
  }

  /// A [Stream] that will give access to the server's clipboard updates.
  Stream<String> get serverClipBoardStream =>
      _serverClipBoardStreamController.stream;

  /// A [Stream] that will give access to all incoming framebuffer updates.
  Stream<RemoteFrameBufferClientUpdate> get updateStream =>
      _updateStreamController.stream;

  /// Dispose the currently active session and all used resources.
  Future<void> close() async {
    _readLoopRunning = false;
    _writer.match(() {}, (final SocketWriter writer) => writer.close());
    await _incomingMessagesSubscription.match(
      () {},
      (
        final StreamSubscription<RemoteFrameBufferClientReadMessage>
            subscription,
      ) =>
          subscription.cancel(),
    );
    await _updateStreamController.close();
  }

  /// Connect to [hostname] on [port] and perform the protocol handshake,
  /// optionally using [password].
  Future<void> connect({
    required final String hostname,
    final String? password,
    final int port = 5900,
  }) async =>
      (await TaskEither<Object, void>.tryCatch(
        () async {
          _password = optionOf(password);
          final RawSocket socket = await RawSocket.connect(
            hostname,
            port,
          );
          // Small messages (pointer, keys, update requests) must leave at once,
          // not wait for the ACK of the previous one (Nagle).
          socket.setOption(SocketOption.tcpNoDelay, true);
          _socket = some(socket);
          _writer = some(SocketWriter(socket: socket));
        },
        (
          final Object error,
          final _,
        ) =>
            error,
      ).andThen(_performHandshake).run())
          .match(
        (final Object error) {
          // Conserver [SocketException] / [Error] pour l’UI ; sinon envelopper.
          if (error is Error) {
            throw error;
          }
          if (error is Exception) {
            throw error;
          }
          throw Exception(error);
        },
        (final _) {},
      );

  /// Invoke this method to let the package read and handle incoming messages.
  /// If you want to handle incoming messages yourself, directly listen to
  /// [incomingMessages].
  void handleIncomingMessages() {
    _incomingMessagesSubscription = some(
      incomingMessages
          .listen((final RemoteFrameBufferClientReadMessage message) {
        message.when(
          bell: () {},
          frameBufferUpdate:
              (final RemoteFrameBufferFrameBufferUpdateMessage message) {
            Option<RemoteFrameBufferClientCursor> cursor = none();
            final List<RemoteFrameBufferClientUpdateRectangle>
                convertedRectangles =
                <RemoteFrameBufferClientUpdateRectangle>[];
            for (final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle
                in message.rectangles) {
              if (rectangle.encodingType
                  is RemoteFrameBufferEncodingTypeCursor) {
                // Not part of the framebuffer; the last shape wins.
                _decodeCursor(rectangle).match(
                  () {},
                  (final RemoteFrameBufferClientCursor decoded) =>
                      cursor = some(decoded),
                );
              } else {
                convertedRectangles.add(
                  _rectangleConverter.convert(
                    rectangle: rectangle,
                    zrleDecoder: _zrleDecoder,
                    hextileDecoder: _hextileDecoder,
                    pixelConverter: _pixelConverter,
                    zlibDecoder: _zlibDecoder,
                  ),
                );
              }
            }
            _updateStreamController.add(
              RemoteFrameBufferClientUpdate(
                cursor: cursor,
                rectangles: convertedRectangles,
              ),
            );
          },
          serverCutTextMessage:
              (final RemoteFrameBufferServerCutTextMessage message) =>
                  _serverClipBoardStreamController.add(message.text),
          setColorMapEntries: () {},
        );
      }),
    );
  }

  /// Request a framebuffer update from the server.
  /// With [pipelineUpdateRequests], call it once after [handleIncomingMessages]
  /// and the client keeps requesting by itself. Otherwise, call it once you are
  /// finished processing any received updates.
  ///
  /// With [incremental] (the default), the server sends only what changed.
  /// Set it to `false` to ask for the whole screen again, e.g. to repaint
  /// areas a server left stale. With [pipelineUpdateRequests], such a request
  /// is one more pending request: servers merge pending requests, so the
  /// pipeline stays one request deep.
  void requestUpdate({final bool incremental = true}) => _socket.match(
        () {},
        (final _) => _config.match(
          () {},
          (final Config config) {
            final RemoteFrameBufferFrameBufferUpdateRequestMessage
                requestMessage =
                RemoteFrameBufferFrameBufferUpdateRequestMessage(
              height: config.frameBufferHeight,
              incremental: incremental,
              width: config.frameBufferWidth,
              x: 0,
              y: 0,
            );
            logger.log(Level.INFO, '> $requestMessage');
            _write(
              requestMessage.toBytes().asUint8List(),
            );
          },
        ),
      );

  void sendClientCutText({
    required final String text,
  }) =>
      _socket.match(
        () {},
        (final RawSocket socket) {
          final RemoteFrameBufferClientCutTextMessage message =
              RemoteFrameBufferClientCutTextMessage(text: text);
          logger.info('> $message');
          _write(message.toBytes().buffer.asUint8List());
        },
      );

  void sendKeyEvent({
    required final RemoteFrameBufferClientKeyEvent keyEvent,
  }) =>
      _socket.match(
        () {},
        (final RawSocket socket) {
          final RemoteFrameBufferKeyEventMessage message =
              RemoteFrameBufferKeyEventMessage(
            down: keyEvent.down,
            key: keyEvent.key,
          );
          logger.info('> $message');
          _write(message.toBytes().asUint8List());
        },
      );

  void sendPointerEvent({
    required final RemoteFrameBufferClientPointerEvent pointerEvent,
  }) =>
      _socket.match(
        () {},
        (final RawSocket socket) {
          final RemoteFrameBufferPointerEventMessage message =
              RemoteFrameBufferPointerEventMessage(
            button1Down: pointerEvent.button1Down,
            button2Down: pointerEvent.button2Down,
            button3Down: pointerEvent.button3Down,
            button4Down: pointerEvent.button4Down,
            button5Down: pointerEvent.button5Down,
            button6Down: pointerEvent.button6Down,
            button7Down: pointerEvent.button7Down,
            button8Down: pointerEvent.button8Down,
            x: pointerEvent.x,
            y: pointerEvent.y,
          );
          logger.info('> $message');
          _write(message.toBytes().asUint8List());
        },
      );

  Option<RemoteFrameBufferClientCursor> _decodeCursor(
    final RemoteFrameBufferFrameBufferUpdateMessageRectangle rectangle,
  ) =>
      _cursorDecoder.match(
        () {
          logger.warning('Received a cursor but decoder is not initialised');
          return none();
        },
        (final CursorDecoder decoder) {
          try {
            return some(
              decoder.decode(
                data: rectangle.pixelData,
                width: rectangle.width,
                height: rectangle.height,
                hotspotX: rectangle.x,
                hotspotY: rectangle.y,
              ),
            );
          } on FormatException catch (error) {
            logger.warning('Failed to decode cursor: $error');
            return none();
          }
        },
      );

  TaskEither<Object, void> _handleSecurityType({
    required final RawSocket socket,
  }) =>
      _password.match(
        () => TaskEither<Object, void>.of(null),
        (final String password) => TaskEither<Object, void>.tryCatch(
          () async {
            final ByteData challenge = await socket.readSync(length: 16).run();
            logger.info('< Security challenge');
            final ByteData encodedAndTruncatedPassword = ByteData.sublistView(
              Uint8List.fromList(ascii.encode(password).take(8).toList()),
            );
            final ByteData key = ByteData(8);
            for (int i = 0; i < 8; i++) {
              int byte;
              if (i < encodedAndTruncatedPassword.lengthInBytes) {
                byte = encodedAndTruncatedPassword.getUint8(i);
              } else {
                byte = 0;
              }
              byte = byte.reverseBits();
              key.setUint8(i, byte);
            }
            final ByteData response = ByteData.sublistView(
              Uint8List.fromList(
                DES(
                  key: key.asUint8List(),
                  mode: DESMode.ECB,
                  paddingType: DESPaddingType.PKCS7,
                ).encrypt(challenge.asUint8List()),
              ),
              0,
              16,
            );
            logger.info('> Security challenge response');
            _write(
              response.buffer
                  .asUint8List(response.offsetInBytes, response.lengthInBytes),
            );
          },
          (final Object error, final _) => error,
        ),
      );

  TaskEither<Object, void> _performHandshake() => _socket.match(
        () => TaskEither<Object, void>.left('Error using socket'),
        (final RawSocket socket) => _readProtocolVersionMessage(socket: socket)
            .andThen(() => _sendProtocolVersionMessage(socket: socket))
            .andThen(() => _readSecurityHandshake(socket: socket))
            .andThen(() => _sendSecurityType(socket: socket))
            .andThen(() => _handleSecurityType(socket: socket))
            .andThen(() => _readSecurityResultMessage(socket: socket))
            .andThen(() => _sendClientInitMessage(socket: socket))
            .andThen(() => _readServerInitMessage(socket: socket))
            .andThen(() => _setPixelFormat(socket: socket))
            .andThen(() => _setEncodingTypes(socket: socket)),
      );

  TaskEither<Object, void> _readProtocolVersionMessage({
    required final RawSocket socket,
  }) =>
      TaskEither<Object, void>.tryCatch(
        () async {
          final RemoteFrameBufferProtocolVersionHandshakeMessage
              protocolVersionHandshakeMessage =
              RemoteFrameBufferProtocolVersionHandshakeMessage.fromBytes(
            bytes: await socket
                .readSync(
                  length:
                      RemoteFrameBufferProtocolVersionHandshakeMessage.length,
                )
                .run(),
          );
          logger.log(Level.INFO, '< $protocolVersionHandshakeMessage');
          if (protocolVersionHandshakeMessage.version
              is RemoteFrameBufferProtocolVersionUnknown) {
            throw Exception(
              'Unsupported server protocol version: ${protocolVersionHandshakeMessage.version}',
            );
          } else {
            _selectedProtocolVersion =
                some(protocolVersionHandshakeMessage.version);
          }
        },
        (final Object error, final _) => error,
      );

  TaskEither<Object, void> _readSecurityHandshake({
    required final RawSocket socket,
  }) {
    final TaskEither<Object, void> taskEitherWithList =
        TaskEither<Object, void>.tryCatch(
      () async {
        final int numberOfSecurityTypes =
            (await socket.readSync(length: 1).run()).getUint8(0);
        logger.log(
          Level.INFO,
          '< numberOfSecurityTypes=$numberOfSecurityTypes',
        );
        if (numberOfSecurityTypes == 0) {
          // Error, next 4 bytes is reason-length, then reason-string
          final int reasonLength =
              (await socket.readSync(length: 4).run()).getUint32(0);
          final String reason = ascii.decode(
            (await socket.readSync(length: reasonLength).run())
                .buffer
                .asUint8List(),
          );
          throw Exception(
            'Error reading security handshake message: $reason',
          );
        } else {
          final RemoteFrameBufferSecurityHandshakeMessage
              securityResultHandshakeMessage =
              RemoteFrameBufferSecurityHandshakeMessage.fromBytes(
            bytes: ByteData.sublistView(
              Uint8List.fromList(
                <int>[
                  numberOfSecurityTypes,
                  ...(await socket
                          .readSync(length: numberOfSecurityTypes)
                          .run())
                      .buffer
                      .asUint8List(),
                ],
              ),
            ),
          );
          logger.log(Level.INFO, '< $securityResultHandshakeMessage');
          if (_password.isNone() &&
              securityResultHandshakeMessage.securityTypes.notElem(
                const RemoteFrameBufferSecurityType.none(),
              )) {
            throw Exception(
              'Server does not support security type "none", but not password was provided',
            );
          }
          if (_password.isSome() &&
              securityResultHandshakeMessage.securityTypes.notElem(
                const RemoteFrameBufferSecurityType.vncAuthentication(),
              )) {
            throw Exception(
              'Server does not support security type "vncAuthentication"',
            );
          }
        }
      },
      (final Object error, final _) => error,
    );
    final TaskEither<Object, void> taskEitherWithoutList =
        TaskEither<Object, void>.tryCatch(
      () async {
        final RemoteFrameBufferSecurityType securityType =
            RemoteFrameBufferSecurityType.fromBytes(
          bytes: await socket.readSync(length: 4).run(),
        );
        logger.info('< $securityType');

        if (_password.isNone() &&
            securityType != const RemoteFrameBufferSecurityType.none()) {
          throw Exception(
            'Server does not support security type "none", but not password was provided',
          );
        }
        if (_password.isSome() &&
            securityType !=
                const RemoteFrameBufferSecurityType.vncAuthentication()) {
          throw Exception(
            'Server does not support security type "vncAuthentication"',
          );
        }
        _selectedSecurityType = some(securityType);
      },
      (final Object error, final _) => error,
    );
    return _selectedProtocolVersion
        .getOrElse(
          () => throw Exception('Protocol version has not been chosen yet'),
        )
        .map(
          unknown: (final _) => throw Exception('Unknown protocol version'),
          v3_3: (final _) => taskEitherWithoutList,
          v3_7: (final _) => taskEitherWithList,
          v3_8: (final _) => taskEitherWithList,
        );
  }

  TaskEither<Object, void> _readSecurityResultMessage({
    required final RawSocket socket,
  }) {
    final TaskEither<Object, void> taskEitherWithErrorMessage =
        TaskEither<Object, void>.tryCatch(
      () async {
        final RemoteFrameBufferSecurityResultHandshakeMessage
            securityResultHandshakeMessage =
            RemoteFrameBufferSecurityResultHandshakeMessage.fromBytes(
          bytes: await socket.readSync(length: 4).run(),
        );
        logger.log(Level.INFO, '< $securityResultHandshakeMessage');
        if (!securityResultHandshakeMessage.success) {
          final int reasonLength =
              (await socket.readSync(length: 4).run()).getUint32(0);
          final String reason = ascii.decode(
            (await socket.readSync(length: reasonLength).run())
                .buffer
                .asUint8List(),
          );
          throw Exception('Error reading security result message: $reason');
        }
      },
      (final Object error, final _) => error,
    );
    final TaskEither<Object, void> taskEitherWithoutErrorMessage =
        TaskEither<Object, void>.tryCatch(
      () async {
        final RemoteFrameBufferSecurityResultHandshakeMessage
            securityResultHandshakeMessage =
            RemoteFrameBufferSecurityResultHandshakeMessage.fromBytes(
          bytes: await socket.readSync(length: 4).run(),
        );
        logger.log(Level.INFO, '< $securityResultHandshakeMessage');
        if (!securityResultHandshakeMessage.success) {
          throw Exception('Security handshake failed');
        }
      },
      (final Object error, final _) => error,
    );
    return _selectedProtocolVersion
        .getOrElse(() => throw Exception('Protocol version not chosen yet'))
        .map(
          unknown: (final _) => throw Exception('Unknown protocol version'),
          v3_3: (final _) => _selectedSecurityType
              .getOrElse(() => throw Exception('Security type not chosen yet'))
              .map(
                invalid: (final _) => throw Exception('Invalid security type'),
                none: (final _) => TaskEither<Object, void>.of(null),
                vncAuthentication: (final _) => taskEitherWithoutErrorMessage,
              ),
          v3_7: (final _) => _selectedSecurityType
              .getOrElse(() => throw Exception('Security type not chosen yet'))
              .map(
                invalid: (final _) => throw Exception('Invalid security type'),
                none: (final _) => TaskEither<Object, void>.of(null),
                vncAuthentication: (final _) => taskEitherWithoutErrorMessage,
              ),
          v3_8: (final _) => taskEitherWithErrorMessage,
        );
  }

  TaskEither<Object, void> _readServerInitMessage({
    required final RawSocket socket,
  }) =>
      RemoteFrameBufferServerInitMessage.readFromSocket(socket: socket)
          .map((final RemoteFrameBufferServerInitMessage serverInitMessage) {
        _config = some(
          Config(
            frameBufferHeight: serverInitMessage.frameBufferHeightInPixels,
            frameBufferWidth: serverInitMessage.frameBufferWidthInPixels,
            pixelFormat: serverInitMessage.serverPixelFormat,
          ),
        );
      });

  TaskEither<Object, void> _sendClientInitMessage({
    required final RawSocket socket,
  }) =>
      TaskEither<Object, void>.tryCatch(
        () async {
          logger.log(
            Level.INFO,
            '> ${const RemoteFrameBufferClientInitMessage(sharedFlag: true)}',
          );
          _write(
            const RemoteFrameBufferClientInitMessage(sharedFlag: true)
                .toBytes()
                .asUint8List(),
          );
        },
        (final Object error, final _) => error,
      );

  TaskEither<Object, void> _sendProtocolVersionMessage({
    required final RawSocket socket,
  }) =>
      TaskEither<Object, void>.tryCatch(
        () async {
          final RemoteFrameBufferProtocolVersionHandshakeMessage message =
              RemoteFrameBufferProtocolVersionHandshakeMessage(
            version: _selectedProtocolVersion.getOrElse(
              () => throw Exception('Error selecting protocol version'),
            ),
          );
          logger.log(Level.INFO, '> $message');
          _write(message.toBytes().asUint8List());
        },
        (final Object error, final _) => error,
      );

  TaskEither<Object, void> _sendSecurityType({
    required final RawSocket socket,
  }) {
    final TaskEither<Object, void> taskEither =
        TaskEither<Object, void>.tryCatch(
      () async {
        final RemoteFrameBufferSecurityType securityType = _password.match(
          () => const RemoteFrameBufferSecurityType.none(),
          (final _) => const RemoteFrameBufferSecurityType.vncAuthentication(),
        );
        logger.info('> $securityType');
        _selectedSecurityType = some(securityType);
        _write(securityType.toBytes().asUint8List());
      },
      (final Object error, final _) => error,
    );
    return _selectedProtocolVersion
        .getOrElse(() => throw Exception('Protocol version not chosen yet'))
        .map(
          unknown: (final _) => throw Exception('Unknown protocol version'),
          v3_3: (final _) => TaskEither<Object, void>.of(null),
          v3_7: (final _) => taskEither,
          v3_8: (final _) => taskEither,
        );
  }

  TaskEither<Object, void> _setEncodingTypes({
    required final RawSocket socket,
  }) =>
      TaskEither<Object, void>.tryCatch(
        () async {
          final RemoteFrameBufferSetEncodingsMessage message =
              RemoteFrameBufferSetEncodingsMessage(
            encodingTypes: <RemoteFrameBufferEncodingType>[
              ..._encodings,
              // Pseudo-encodings come after the real ones.
              if (_localCursor) const RemoteFrameBufferEncodingType.cursor(),
            ],
          );
          logger.info('> $message');
          _write(message.toBytes().buffer.asUint8List());
        },
        (final Object error, final _) => error,
      );

  TaskEither<Object, void> _setPixelFormat({
    required final RawSocket socket,
  }) =>
      TaskEither<Object, void>.tryCatch(
        () async {
          final RemoteFrameBufferSetPixelFormatMessage message =
              RemoteFrameBufferSetPixelFormatMessage(
            pixelFormat: _pixelFormat,
          );
          final PixelConverter converter =
              PixelConverter(pixelFormat: message.pixelFormat);
          _pixelConverter = some(converter);
          _cursorDecoder = some(CursorDecoder(converter: converter));
          _hextileDecoder = some(HextileDecoder(converter: converter));
          _zlibDecoder = some(ZlibDecoder(converter: converter));
          _zrleDecoder = some(ZrleDecoder.withConverter(converter: converter));
          logger.info('> $message');
          _write(message.toBytes().buffer.asUint8List());
          // From now on the server sends pixels in our format: Raw rectangle
          // sizes must use its bits per pixel, not the server's native one.
          _config = _config.map(
            (final Config config) =>
                config.copyWith(pixelFormat: message.pixelFormat),
          );
        },
        (final Object error, final _) => error,
      );

  void _write(final Uint8List bytes) => _writer.match(
        () {},
        (final SocketWriter writer) => writer.write(bytes),
      );
}
