# Qt 4 Hextile fixture

Three FramebufferUpdate messages from a "Qt for Embedded Linux VNC Server"
(800x480, rgb565, 16x16 Hextile rectangles), captured on 2026-11-18 (J370):

- `updates.bin.gz`: the server bytes of the first three updates, as sent;
- `frame_NNN.bgra.gz`: the expected framebuffer (opaque BGRA8888) after
  update NNN, produced by an independent Python decoder written from
  RFC 6143 §7.7.4, not by dart_rfb.

Update 0 is a full screen of 1500 tiles (Raw, background only, dual colour
and coloured subrectangles); update 1 repaints 30 tiles as background only,
update 2 draws them again with subrectangles.
