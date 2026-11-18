## 0.0.1

- Initial version.

## 0.0.2

- Fix pub score issues

## 0.1.0

- Implement VncAuthentication security type (aka, using a password)

## 0.2.0

- Add support for protocol versions 3.3 and 3.7

## 0.3.0

- Add support for pointer events
- Properly use the `logging` package

## 0.3.1

- Fix a minor typo issue

## 0.4.0

- Add CopyRect encoding support
- Add SetEncodings message support
- Add SetPixelFormat message support

## 0.4.1

- Fix [issue #9](https://github.com/Goddchen/dart-rfb/issues/9) (hanging after some time)

## 0.5.0

- Add key event support

## 0.6.0

- Add clipboard support

## 0.7.0

- Refactoring: replace `startReadLoop()` with `Stream<RemoteFrameBufferClientReadMessage> incomingMessages` and `void handleIncomingMessages()`

## 0.8.0
- Upgrade `binary` to 4.0.0
- Manage Dart SDK via `fvm`

## 0.9.0
- Add full support for the ZRLE encoding ( thanks @Spokplacenta )

## Unreleased

- Enable `TCP_NODELAY` on the client socket: small messages (pointer, keys, update requests) no longer wait for the ACK of the previous one (Nagle)
- Pipeline framebuffer update requests: the client sends the next incremental `FramebufferUpdateRequest` as soon as it reads the header of an update, instead of waiting for the caller to finish rendering. New `RemoteFrameBufferClient(pipelineUpdateRequests:)` option, `true` by default; with it, call `requestUpdate()` once after `handleIncomingMessages()`
- Fix: `config.pixelFormat` is the format set with SetPixelFormat (32 bpp), so Raw rectangle sizes no longer use the server's native bits per pixel
- Fix: wait for the colors of a `SetColorMapEntries` message before reading the next message
- Fix: retry partial socket writes (`SocketWriter`), in order, instead of truncating messages
- Tests: fix stale ZRLE expectations (opaque alpha, one decoder per zlib stream)
- **Breaking default**: the client asks for 16 bpp RGB565 by default instead of 32 bpp. New `RemoteFrameBufferClient(pixelFormat:)` option with the presets `RemoteFrameBufferPixelFormat.rgb565` (default), `.bgr233` (8 bpp, 2 bits per component, as RealVNC Viewer on slow links) and `.bgra8888` (the previous format). Updates are still delivered as opaque BGRA8888 pixels, whatever the format
- ZRLE: CPIXEL of 1, 2 or 3 bytes depending on the pixel format (RFC 6143 §7.7.6); Raw rectangles are converted to BGRA8888 too, through a lookup table at 8 and 16 bpp (`PixelConverter`)
- ZRLE decoder writes 32-bit pixels directly (`Uint32List`, `fillRange` for solid tiles and runs, reused palette) and inflates without a `List<int>` copy: 3 to 5 times faster
- `RemoteFrameBufferPixelFormat.bgra8888` is now `const`
- Add the Cursor pseudo-encoding (-239, RFC 6143 §7.8.1), opt-in with `RemoteFrameBufferClient(localCursor: true)`: the server stops drawing the cursor into the framebuffer and sends its shape, delivered as `RemoteFrameBufferClientUpdate.cursor` (`RemoteFrameBufferClientCursor`: BGRA8888 pixels whose alpha comes from the bitmask, hotspot, `isVisible` false for a 0x0 cursor). Cursor rectangles are no longer part of `RemoteFrameBufferClientUpdate.rectangles`. Pixels in 8, 16 or 32 bpp go through `PixelConverter`
- `RemoteFrameBufferEncodingType` has a new `cursor` case: exhaustive `map`/`when` calls must handle it
- Fix pointer and key events never sent while updates keep arriving (slow link with pipelined requests, or a client slower than the link): the read loop busy-waited on microtasks only, so the isolate never handled its other events. `readSync` now waits through a timer, and the read loop gives the event loop one turn per message
