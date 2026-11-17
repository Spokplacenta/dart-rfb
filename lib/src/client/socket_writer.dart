import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

/// Writes whole messages to a [RawSocket].
///
/// [RawSocket.write] may write only part of the bytes when the socket's send
/// buffer is full. The remainder is queued and retried later, so messages are
/// never truncated and always leave in the order they were written.
class SocketWriter {
  /// Delay between two attempts to flush pending bytes.
  static const Duration retryDelay = Duration(milliseconds: 1);

  final Queue<Uint8List> _pending = Queue<Uint8List>();
  final RawSocket _socket;
  Timer? _retryTimer;

  SocketWriter({required final RawSocket socket}) : _socket = socket;

  /// Whether some bytes are still waiting to be written.
  bool get hasPendingBytes => _pending.isNotEmpty;

  /// Stop retrying and drop the bytes that are still pending.
  void close() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pending.clear();
  }

  /// Write all of [bytes], now if possible, otherwise as soon as the socket
  /// accepts them.
  void write(final Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }
    _pending.add(bytes);
    _flush();
  }

  void _flush() {
    while (_pending.isNotEmpty) {
      final Uint8List bytes = _pending.first;
      final int written = _socket.write(bytes);
      if (written >= bytes.length) {
        _pending.removeFirst();
        continue;
      }
      if (written > 0) {
        _pending
          ..removeFirst()
          ..addFirst(Uint8List.sublistView(bytes, written));
      }
      _retryTimer ??= Timer(retryDelay, () {
        _retryTimer = null;
        try {
          _flush();
        } on SocketException {
          // The socket is gone; the read loop reports the disconnection.
          close();
        }
      });
      return;
    }
  }
}
