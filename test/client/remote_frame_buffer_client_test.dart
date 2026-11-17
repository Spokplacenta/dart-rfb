import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_rfb/dart_rfb.dart';
import 'package:dart_rfb/src/client/remote_frame_buffer_client_read_message.dart';
import 'package:dart_rfb/src/client/socket_writer.dart';
import 'package:test/test.dart';

/// A step run by the fake server after the handshake.
sealed class _Step {
  const _Step();
}

/// Read [length] bytes from the client and report them, or report `null`
/// if they do not arrive within a second.
class _Read extends _Step {
  final int length;

  const _Read(this.length);
}

/// Wait [milliseconds] without reporting anything.
class _Wait extends _Step {
  final int milliseconds;

  const _Wait(this.milliseconds);
}

/// Send [bytes] to the client.
class _Send extends _Step {
  final List<int> bytes;

  const _Send(this.bytes);
}

/// Wait [milliseconds], then report how many unread bytes the client sent.
class _Silence extends _Step {
  final int milliseconds;

  const _Silence(this.milliseconds);
}

/// A RFC 6143 server reduced to what these tests need, on loopback.
///
/// It runs in its own isolate and follows a fixed script: while the client
/// waits for data in `readSync`, it does not yield to the event loop of its
/// isolate, so a server living in that same isolate could never answer.
class _FakeServer {
  final Isolate _isolate;
  final int port;

  /// What the server read after the handshake: SetPixelFormat and
  /// SetEncodings first, then one entry per [_Read] or [_Silence] step.
  final Future<List<Object?>> reports;

  _FakeServer._(this._isolate, this.port, this.reports);

  static Future<_FakeServer> start(final List<_Step> steps) async {
    final ReceivePort receivePort = ReceivePort();
    final Isolate isolate = await Isolate.spawn(
      _runServer,
      <Object>[receivePort.sendPort, steps],
    );
    final StreamIterator<Object?> messages =
        StreamIterator<Object?>(receivePort);
    await messages.moveNext();
    final int port = messages.current! as int;
    final Completer<List<Object?>> reports = Completer<List<Object?>>();
    unawaited(() async {
      final List<Object?> received = <Object?>[];
      while (await messages.moveNext() && messages.current != 'done') {
        received.add(messages.current);
      }
      reports.complete(received);
      await messages.cancel();
    }());
    return _FakeServer._(isolate, port, reports.future);
  }

  void kill() => _isolate.kill(priority: Isolate.immediate);
}

Future<void> _runServer(final List<Object> args) async {
  final SendPort reportPort = args[0] as SendPort;
  final List<_Step> steps = args[1] as List<_Step>;
  final ServerSocket serverSocket =
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  reportPort.send(serverSocket.port);
  // Lives until the isolate is killed.
  // ignore: close_sinks
  final Socket socket = await serverSocket.first;
  socket.setOption(SocketOption.tcpNoDelay, true);
  final BytesBuilder buffer = BytesBuilder();
  Completer<void>? dataAvailable;
  socket.listen((final Uint8List data) {
    buffer.add(data);
    dataAvailable?.complete();
    dataAvailable = null;
  });
  Future<Uint8List?> read(final int length) async {
    while (buffer.length < length) {
      dataAvailable = Completer<void>();
      await dataAvailable!.future;
    }
    final Uint8List all = buffer.takeBytes();
    buffer.add(Uint8List.sublistView(all, length));
    return Uint8List.sublistView(all, 0, length);
  }

  socket.add('RFB 003.008\n'.codeUnits);
  await read(12); // client version
  socket.add(<int>[1, 1]); // one security type: none
  await read(1); // chosen security type
  socket.add(<int>[0, 0, 0, 0]); // security result: OK
  await read(1); // ClientInit
  // A native 16 bpp (RGB565) server of 4x2 pixels named "A".
  final ByteData serverInit = ByteData(24)
    ..setUint16(0, 4)
    ..setUint16(2, 2)
    ..setUint8(4, 16)
    ..setUint8(5, 16)
    ..setUint8(7, 1)
    ..setUint16(8, 31)
    ..setUint16(10, 63)
    ..setUint16(12, 31)
    ..setUint8(14, 11)
    ..setUint8(15, 5)
    ..setUint32(20, 1);
  socket.add(<int>[...serverInit.buffer.asUint8List(), 0x41]);
  // SetPixelFormat (20 bytes) and SetEncodings (4 + 3 * 4 bytes).
  reportPort.send(await read(20 + 16));
  for (final _Step step in steps) {
    switch (step) {
      case _Read(:final int length):
        reportPort.send(
          await read(length).timeout(
            const Duration(seconds: 1),
            onTimeout: () => null,
          ),
        );
      case _Wait(:final int milliseconds):
        await Future<void>.delayed(Duration(milliseconds: milliseconds));
      case _Send(:final List<int> bytes):
        socket.add(bytes);
        await socket.flush();
      case _Silence(:final int milliseconds):
        await Future<void>.delayed(Duration(milliseconds: milliseconds));
        reportPort.send(buffer.length);
    }
  }
  reportPort.send('done');
}

/// Accepts a fixed number of bytes per [write] call, to simulate a full send
/// buffer.
class _PartialWriteSocket implements RawSocket {
  final List<int> acceptedPerCall;
  final BytesBuilder received = BytesBuilder();
  int calls = 0;

  _PartialWriteSocket(this.acceptedPerCall);

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);

  @override
  int write(final List<int> buffer, [final int offset = 0, final int? count]) {
    final int end = count == null ? buffer.length : offset + count;
    final int accepted =
        calls < acceptedPerCall.length ? acceptedPerCall[calls] : end - offset;
    calls++;
    final int written = accepted.clamp(0, end - offset);
    received.add(buffer.sublist(offset, offset + written));
    return written;
  }
}

/// Header of a FramebufferUpdate with one Raw rectangle of 2x1 pixels.
const List<int> _rawUpdateHeader = <int>[
  0, 0, 0, 1, // type, padding, 1 rectangle
  0, 0, 0, 0, 0, 2, 0, 1, // x, y, width 2, height 1
  0, 0, 0, 0, // encoding Raw
];

/// The 2x1 pixels of [_rawUpdateHeader], at 32 bpp.
const List<int> _rawPixels = <int>[1, 2, 3, 4, 5, 6, 7, 8];

void main() {
  final List<_FakeServer> servers = <_FakeServer>[];
  final List<RemoteFrameBufferClient> clients = <RemoteFrameBufferClient>[];

  /// Connects a client asking for [pixelFormat], or for the default format
  /// when it is `null`. Most tests use 32 bpp, so that a pixel is 4 bytes on
  /// the wire and in the update.
  Future<(RemoteFrameBufferClient, _FakeServer)> connect(
    final List<_Step> steps, {
    final bool pipelineUpdateRequests = true,
    final RemoteFrameBufferPixelFormat? pixelFormat =
        RemoteFrameBufferPixelFormat.bgra8888,
  }) async {
    final _FakeServer server = await _FakeServer.start(steps);
    servers.add(server);
    final RemoteFrameBufferClient client = pixelFormat == null
        ? RemoteFrameBufferClient(
            pipelineUpdateRequests: pipelineUpdateRequests,
          )
        : RemoteFrameBufferClient(
            pipelineUpdateRequests: pipelineUpdateRequests,
            pixelFormat: pixelFormat,
          );
    clients.add(client);
    await client.connect(hostname: '127.0.0.1', port: server.port);
    return (client, server);
  }

  tearDown(() async {
    for (final _FakeServer server in servers) {
      server.kill();
    }
    servers.clear();
    for (final RemoteFrameBufferClient client in clients) {
      client.socket.match(
        () {},
        (final RawSocket socket) => unawaited(socket.close()),
      );
      // The read loop only stops once a message arrives: do not wait for it.
      await client.close().timeout(
            const Duration(milliseconds: 100),
            onTimeout: () {},
          );
    }
    clients.clear();
  });

  test('connect disables Nagle (TCP_NODELAY)', () async {
    final (RemoteFrameBufferClient client, _) = await connect(const <_Step>[]);
    // TCP_NODELAY is option 1 of IPPROTO_TCP on Linux, macOS and Windows.
    final Uint8List value = client.socket.toNullable()!.getRawOption(
          RawSocketOption(RawSocketOption.levelTcp, 1, Uint8List(4)),
        );
    expect(value.any((final int byte) => byte != 0), isTrue);
  });

  for (final (
        String name,
        RemoteFrameBufferPixelFormat? requested,
        RemoteFrameBufferPixelFormat expected
      ) in <(
    String,
    RemoteFrameBufferPixelFormat?,
    RemoteFrameBufferPixelFormat
  )>[
    ('default', null, RemoteFrameBufferPixelFormat.rgb565),
    (
      'bgr233',
      RemoteFrameBufferPixelFormat.bgr233,
      RemoteFrameBufferPixelFormat.bgr233
    ),
    (
      'rgb565',
      RemoteFrameBufferPixelFormat.rgb565,
      RemoteFrameBufferPixelFormat.rgb565
    ),
    (
      'bgra8888',
      RemoteFrameBufferPixelFormat.bgra8888,
      RemoteFrameBufferPixelFormat.bgra8888
    ),
  ]) {
    test('$name: sends SetPixelFormat and uses it in config', () async {
      final (RemoteFrameBufferClient client, _FakeServer server) =
          await connect(const <_Step>[], pixelFormat: requested);
      expect(client.config.toNullable()!.pixelFormat, expected);
      final Uint8List setPixelFormat =
          (await server.reports).first! as Uint8List;
      expect(setPixelFormat.sublist(0, 20), <int>[
        0, 0, 0, 0, // SetPixelFormat, padding
        ...expected.toBytes().buffer.asUint8List(),
      ]);
    });
  }

  test('rgb565 Raw rectangle is read at 16 bpp and converted to BGRA',
      () async {
    final (RemoteFrameBufferClient client, _) = await connect(
      const <_Step>[
        _Read(10),
        // Red then blue, little endian, followed by a Bell.
        _Send(<int>[..._rawUpdateHeader, 0x00, 0xF8, 0x1F, 0x00, 2]),
      ],
      pipelineUpdateRequests: false,
      pixelFormat: null,
    );
    final Future<RemoteFrameBufferClientUpdate> update =
        client.updateStream.first;
    client
      ..handleIncomingMessages()
      ..requestUpdate();
    expect(
      (await update).rectangles.single.byteData.buffer.asUint8List(),
      <int>[0, 0, 255, 255, 255, 0, 0, 255],
    );
  });

  test('Raw rectangle size uses the client pixel format', () async {
    // 2 pixels at 32 bpp = 8 bytes, then a Bell. With the server's 16 bpp,
    // the client would read 4 bytes and take the rest as message types.
    final (RemoteFrameBufferClient client, _) = await connect(
      const <_Step>[
        _Send(<int>[..._rawUpdateHeader, ..._rawPixels, 2]),
      ],
      pipelineUpdateRequests: false,
    );
    final StreamIterator<RemoteFrameBufferClientReadMessage> messages =
        StreamIterator<RemoteFrameBufferClientReadMessage>(
      client.incomingMessages,
    );
    expect(await messages.moveNext(), isTrue);
    final RemoteFrameBufferFrameBufferUpdateMessage update =
        messages.current.whenOrNull(
      frameBufferUpdate:
          (final RemoteFrameBufferFrameBufferUpdateMessage message) => message,
    )!;
    expect(
      update.rectangles.single.pixelData.buffer.asUint8List(),
      _rawPixels,
    );
    expect(await messages.moveNext(), isTrue);
    expect(messages.current, const RemoteFrameBufferClientReadMessage.bell());
    unawaited(messages.cancel());
  });

  test('SetColorMapEntries is read completely before the next message',
      () async {
    final (RemoteFrameBufferClient client, _) = await connect(
      <_Step>[
        // The colors arrive later than the header: the client must wait for
        // them instead of reading them as the next message type.
        const _Send(<int>[1, 0, 0, 0, 0, 2]), // first color 0, 2 colors
        const _Wait(50),
        _Send(<int>[...List<int>.filled(2 * 6, 9), 2]), // colors, then Bell
      ],
      pipelineUpdateRequests: false,
    );
    final StreamIterator<RemoteFrameBufferClientReadMessage> messages =
        StreamIterator<RemoteFrameBufferClientReadMessage>(
      client.incomingMessages,
    );
    expect(await messages.moveNext(), isTrue);
    expect(
      messages.current,
      const RemoteFrameBufferClientReadMessage.setColorMapEntries(),
    );
    expect(await messages.moveNext(), isTrue);
    expect(messages.current, const RemoteFrameBufferClientReadMessage.bell());
    unawaited(messages.cancel());
  });

  test('pipelining requests the next update as soon as a header is read',
      () async {
    final (RemoteFrameBufferClient client, _FakeServer server) = await connect(
      const <_Step>[
        _Read(10), // first request, sent by the caller
        _Send(_rawUpdateHeader), // header only, pixels not sent yet
        _Read(10), // must arrive before the pixels are sent
        _Send(_rawPixels),
        _Silence(100),
      ],
    );
    final Future<RemoteFrameBufferClientUpdate> update =
        client.updateStream.first;
    client
      ..handleIncomingMessages()
      ..requestUpdate();
    expect((await update).rectangles.single.byteData.lengthInBytes, 8);
    final List<Object?> reports = await server.reports;
    final Uint8List? pipelinedRequest = reports[2] as Uint8List?;
    expect(pipelinedRequest, isNotNull);
    expect(pipelinedRequest![0], 3); // FramebufferUpdateRequest
    expect(pipelinedRequest[1], 1); // incremental
    // Exactly one pipelined request per update.
    expect(reports[3], 0);
  });

  test('without pipelining, the client waits for requestUpdate', () async {
    final (RemoteFrameBufferClient client, _FakeServer server) = await connect(
      const <_Step>[
        _Read(10),
        _Send(<int>[..._rawUpdateHeader, ..._rawPixels]),
        _Silence(100),
      ],
      pipelineUpdateRequests: false,
    );
    final Future<RemoteFrameBufferClientUpdate> update =
        client.updateStream.first;
    client
      ..handleIncomingMessages()
      ..requestUpdate();
    await update;
    expect((await server.reports)[2], 0);
  });

  group('SocketWriter', () {
    test('retries partial writes and keeps message order', () async {
      final _PartialWriteSocket socket = _PartialWriteSocket(<int>[3, 0, 2]);
      final SocketWriter writer = SocketWriter(socket: socket)
        ..write(Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]))
        ..write(Uint8List.fromList(<int>[9, 10]));
      expect(socket.received.toBytes(), <int>[1, 2, 3]);
      expect(writer.hasPendingBytes, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        socket.received.toBytes(),
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
      expect(writer.hasPendingBytes, isFalse);
    });

    test('writes at once when the socket accepts everything', () {
      final _PartialWriteSocket socket = _PartialWriteSocket(<int>[]);
      final SocketWriter writer = SocketWriter(socket: socket)
        ..write(Uint8List.fromList(<int>[1, 2]));
      expect(socket.received.toBytes(), <int>[1, 2]);
      expect(writer.hasPendingBytes, isFalse);
    });
  });
}
