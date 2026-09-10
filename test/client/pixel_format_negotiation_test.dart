import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dart_rfb/dart_rfb.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Config.pixelFormat follows SetPixelFormat after 16 bpp ServerInit',
    () async {
      final ReceivePort ready = ReceivePort();
      final Isolate isolate = await Isolate.spawn(
        _bindRgb565Server,
        ready.sendPort,
      );
      final int port = await ready.first as int;
      final RemoteFrameBufferClient client = RemoteFrameBufferClient();
      try {
        await client.connect(
          hostname: InternetAddress.loopbackIPv4.address,
          port: port,
        );
        expect(
          client.config
              .getOrElse(() => throw StateError('config missing'))
              .pixelFormat
              .bitsPerPixel,
          32,
        );
      } finally {
        await client.close();
        isolate.kill(priority: Isolate.immediate);
        ready.close();
      }
    },
  );
}

void _bindRgb565Server(final SendPort sendPort) {
  unawaited(
    ServerSocket.bind(InternetAddress.loopbackIPv4, 0).then(
      (final ServerSocket server) {
        sendPort.send(server.port);
        server.listen((final Socket socket) {
          socket.add(
            Uint8List.fromList(<int>[
              ...ascii.encode('RFB 003.008\n'),
              1,
              1,
              0,
              0,
              0,
              0,
              ..._rgb565ServerInit(),
            ]),
          );
        });
      },
    ),
  );
}

Uint8List _rgb565ServerInit() {
  const RemoteFrameBufferPixelFormat rgb565 = RemoteFrameBufferPixelFormat(
    bitsPerPixel: 16,
    depth: 16,
    bigEndian: false,
    trueColor: true,
    redMax: 31,
    greenMax: 63,
    blueMax: 31,
    redShift: 11,
    greenShift: 5,
    blueShift: 0,
  );
  const String name = 't';
  final ByteData header = ByteData(24)
    ..setUint16(0, 800)
    ..setUint16(2, 480)
    ..setUint32(20, name.length);
  header.buffer.asUint8List().setRange(
        4,
        20,
        rgb565.toBytes().buffer.asUint8List(),
      );
  return Uint8List.fromList(<int>[
    ...header.buffer.asUint8List(),
    ...utf8.encode(name),
  ]);
}
