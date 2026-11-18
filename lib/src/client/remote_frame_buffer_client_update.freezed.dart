// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'remote_frame_buffer_client_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RemoteFrameBufferClientFrameBufferConfig {
  int get height => throw _privateConstructorUsedError;
  int get width => throw _privateConstructorUsedError;

  /// Create a copy of RemoteFrameBufferClientFrameBufferConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RemoteFrameBufferClientFrameBufferConfigCopyWith<
          RemoteFrameBufferClientFrameBufferConfig>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RemoteFrameBufferClientFrameBufferConfigCopyWith<$Res> {
  factory $RemoteFrameBufferClientFrameBufferConfigCopyWith(
          RemoteFrameBufferClientFrameBufferConfig value,
          $Res Function(RemoteFrameBufferClientFrameBufferConfig) then) =
      _$RemoteFrameBufferClientFrameBufferConfigCopyWithImpl<$Res,
          RemoteFrameBufferClientFrameBufferConfig>;
  @useResult
  $Res call({int height, int width});
}

/// @nodoc
class _$RemoteFrameBufferClientFrameBufferConfigCopyWithImpl<$Res,
        $Val extends RemoteFrameBufferClientFrameBufferConfig>
    implements $RemoteFrameBufferClientFrameBufferConfigCopyWith<$Res> {
  _$RemoteFrameBufferClientFrameBufferConfigCopyWithImpl(
      this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RemoteFrameBufferClientFrameBufferConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? height = null,
    Object? width = null,
  }) {
    return _then(_value.copyWith(
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RemoteFrameBufferClientFrameBufferConfigImplCopyWith<$Res>
    implements $RemoteFrameBufferClientFrameBufferConfigCopyWith<$Res> {
  factory _$$RemoteFrameBufferClientFrameBufferConfigImplCopyWith(
          _$RemoteFrameBufferClientFrameBufferConfigImpl value,
          $Res Function(_$RemoteFrameBufferClientFrameBufferConfigImpl) then) =
      __$$RemoteFrameBufferClientFrameBufferConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int height, int width});
}

/// @nodoc
class __$$RemoteFrameBufferClientFrameBufferConfigImplCopyWithImpl<$Res>
    extends _$RemoteFrameBufferClientFrameBufferConfigCopyWithImpl<$Res,
        _$RemoteFrameBufferClientFrameBufferConfigImpl>
    implements _$$RemoteFrameBufferClientFrameBufferConfigImplCopyWith<$Res> {
  __$$RemoteFrameBufferClientFrameBufferConfigImplCopyWithImpl(
      _$RemoteFrameBufferClientFrameBufferConfigImpl _value,
      $Res Function(_$RemoteFrameBufferClientFrameBufferConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of RemoteFrameBufferClientFrameBufferConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? height = null,
    Object? width = null,
  }) {
    return _then(_$RemoteFrameBufferClientFrameBufferConfigImpl(
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$RemoteFrameBufferClientFrameBufferConfigImpl
    implements _RemoteFrameBufferClientFrameBufferConfig {
  const _$RemoteFrameBufferClientFrameBufferConfigImpl(
      {required this.height, required this.width});

  @override
  final int height;
  @override
  final int width;

  @override
  String toString() {
    return 'RemoteFrameBufferClientFrameBufferConfig(height: $height, width: $width)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemoteFrameBufferClientFrameBufferConfigImpl &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.width, width) || other.width == width));
  }

  @override
  int get hashCode => Object.hash(runtimeType, height, width);

  /// Create a copy of RemoteFrameBufferClientFrameBufferConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemoteFrameBufferClientFrameBufferConfigImplCopyWith<
          _$RemoteFrameBufferClientFrameBufferConfigImpl>
      get copyWith =>
          __$$RemoteFrameBufferClientFrameBufferConfigImplCopyWithImpl<
              _$RemoteFrameBufferClientFrameBufferConfigImpl>(this, _$identity);
}

abstract class _RemoteFrameBufferClientFrameBufferConfig
    implements RemoteFrameBufferClientFrameBufferConfig {
  const factory _RemoteFrameBufferClientFrameBufferConfig(
          {required final int height, required final int width}) =
      _$RemoteFrameBufferClientFrameBufferConfigImpl;

  @override
  int get height;
  @override
  int get width;

  /// Create a copy of RemoteFrameBufferClientFrameBufferConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemoteFrameBufferClientFrameBufferConfigImplCopyWith<
          _$RemoteFrameBufferClientFrameBufferConfigImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RemoteFrameBufferClientUpdate {
  /// The new cursor shape, when this update carries one (Cursor
  /// pseudo-encoding, see `RemoteFrameBufferClient(localCursor:)`). The
  /// cursor is not part of the framebuffer: draw it yourself at the pointer.
  Option<RemoteFrameBufferClientCursor> get cursor =>
      throw _privateConstructorUsedError;

  /// The list of [RemoteFrameBufferClientUpdateRectangle]s that make this update.
  /// Cursor rectangles are not in this list, see [cursor].
  Iterable<RemoteFrameBufferClientUpdateRectangle> get rectangles =>
      throw _privateConstructorUsedError;

  /// Create a copy of RemoteFrameBufferClientUpdate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RemoteFrameBufferClientUpdateCopyWith<RemoteFrameBufferClientUpdate>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RemoteFrameBufferClientUpdateCopyWith<$Res> {
  factory $RemoteFrameBufferClientUpdateCopyWith(
          RemoteFrameBufferClientUpdate value,
          $Res Function(RemoteFrameBufferClientUpdate) then) =
      _$RemoteFrameBufferClientUpdateCopyWithImpl<$Res,
          RemoteFrameBufferClientUpdate>;
  @useResult
  $Res call(
      {Option<RemoteFrameBufferClientCursor> cursor,
      Iterable<RemoteFrameBufferClientUpdateRectangle> rectangles});
}

/// @nodoc
class _$RemoteFrameBufferClientUpdateCopyWithImpl<$Res,
        $Val extends RemoteFrameBufferClientUpdate>
    implements $RemoteFrameBufferClientUpdateCopyWith<$Res> {
  _$RemoteFrameBufferClientUpdateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RemoteFrameBufferClientUpdate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cursor = null,
    Object? rectangles = null,
  }) {
    return _then(_value.copyWith(
      cursor: null == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as Option<RemoteFrameBufferClientCursor>,
      rectangles: null == rectangles
          ? _value.rectangles
          : rectangles // ignore: cast_nullable_to_non_nullable
              as Iterable<RemoteFrameBufferClientUpdateRectangle>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RemoteFrameBufferClientUpdateImplCopyWith<$Res>
    implements $RemoteFrameBufferClientUpdateCopyWith<$Res> {
  factory _$$RemoteFrameBufferClientUpdateImplCopyWith(
          _$RemoteFrameBufferClientUpdateImpl value,
          $Res Function(_$RemoteFrameBufferClientUpdateImpl) then) =
      __$$RemoteFrameBufferClientUpdateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Option<RemoteFrameBufferClientCursor> cursor,
      Iterable<RemoteFrameBufferClientUpdateRectangle> rectangles});
}

/// @nodoc
class __$$RemoteFrameBufferClientUpdateImplCopyWithImpl<$Res>
    extends _$RemoteFrameBufferClientUpdateCopyWithImpl<$Res,
        _$RemoteFrameBufferClientUpdateImpl>
    implements _$$RemoteFrameBufferClientUpdateImplCopyWith<$Res> {
  __$$RemoteFrameBufferClientUpdateImplCopyWithImpl(
      _$RemoteFrameBufferClientUpdateImpl _value,
      $Res Function(_$RemoteFrameBufferClientUpdateImpl) _then)
      : super(_value, _then);

  /// Create a copy of RemoteFrameBufferClientUpdate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cursor = null,
    Object? rectangles = null,
  }) {
    return _then(_$RemoteFrameBufferClientUpdateImpl(
      cursor: null == cursor
          ? _value.cursor
          : cursor // ignore: cast_nullable_to_non_nullable
              as Option<RemoteFrameBufferClientCursor>,
      rectangles: null == rectangles
          ? _value.rectangles
          : rectangles // ignore: cast_nullable_to_non_nullable
              as Iterable<RemoteFrameBufferClientUpdateRectangle>,
    ));
  }
}

/// @nodoc

class _$RemoteFrameBufferClientUpdateImpl
    implements _RemoteFrameBufferClientUpdate {
  const _$RemoteFrameBufferClientUpdateImpl(
      {this.cursor = const None<RemoteFrameBufferClientCursor>(),
      required this.rectangles});

  /// The new cursor shape, when this update carries one (Cursor
  /// pseudo-encoding, see `RemoteFrameBufferClient(localCursor:)`). The
  /// cursor is not part of the framebuffer: draw it yourself at the pointer.
  @override
  @JsonKey()
  final Option<RemoteFrameBufferClientCursor> cursor;

  /// The list of [RemoteFrameBufferClientUpdateRectangle]s that make this update.
  /// Cursor rectangles are not in this list, see [cursor].
  @override
  final Iterable<RemoteFrameBufferClientUpdateRectangle> rectangles;

  @override
  String toString() {
    return 'RemoteFrameBufferClientUpdate(cursor: $cursor, rectangles: $rectangles)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemoteFrameBufferClientUpdateImpl &&
            (identical(other.cursor, cursor) || other.cursor == cursor) &&
            const DeepCollectionEquality()
                .equals(other.rectangles, rectangles));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, cursor, const DeepCollectionEquality().hash(rectangles));

  /// Create a copy of RemoteFrameBufferClientUpdate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemoteFrameBufferClientUpdateImplCopyWith<
          _$RemoteFrameBufferClientUpdateImpl>
      get copyWith => __$$RemoteFrameBufferClientUpdateImplCopyWithImpl<
          _$RemoteFrameBufferClientUpdateImpl>(this, _$identity);
}

abstract class _RemoteFrameBufferClientUpdate
    implements RemoteFrameBufferClientUpdate {
  const factory _RemoteFrameBufferClientUpdate(
      {final Option<RemoteFrameBufferClientCursor> cursor,
      required final Iterable<RemoteFrameBufferClientUpdateRectangle>
          rectangles}) = _$RemoteFrameBufferClientUpdateImpl;

  /// The new cursor shape, when this update carries one (Cursor
  /// pseudo-encoding, see `RemoteFrameBufferClient(localCursor:)`). The
  /// cursor is not part of the framebuffer: draw it yourself at the pointer.
  @override
  Option<RemoteFrameBufferClientCursor> get cursor;

  /// The list of [RemoteFrameBufferClientUpdateRectangle]s that make this update.
  /// Cursor rectangles are not in this list, see [cursor].
  @override
  Iterable<RemoteFrameBufferClientUpdateRectangle> get rectangles;

  /// Create a copy of RemoteFrameBufferClientUpdate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemoteFrameBufferClientUpdateImplCopyWith<
          _$RemoteFrameBufferClientUpdateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RemoteFrameBufferClientCursor {
  /// The height in pixels, 0 for an invisible cursor.
  int get height => throw _privateConstructorUsedError;

  /// The x offset of the hotspot, the point of the cursor at the pointer.
  int get hotspotX => throw _privateConstructorUsedError;

  /// The y offset of the hotspot.
  int get hotspotY => throw _privateConstructorUsedError;

  /// [width] x [height] BGRA8888 pixels. The alpha comes from the cursor
  /// bitmask: 255 where the cursor is drawn, 0 elsewhere, and the colour of
  /// transparent pixels is 0, so the pixels are both premultiplied and
  /// straight.
  ByteData get pixels => throw _privateConstructorUsedError;

  /// The width in pixels, 0 for an invisible cursor.
  int get width => throw _privateConstructorUsedError;

  /// Create a copy of RemoteFrameBufferClientCursor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RemoteFrameBufferClientCursorCopyWith<RemoteFrameBufferClientCursor>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RemoteFrameBufferClientCursorCopyWith<$Res> {
  factory $RemoteFrameBufferClientCursorCopyWith(
          RemoteFrameBufferClientCursor value,
          $Res Function(RemoteFrameBufferClientCursor) then) =
      _$RemoteFrameBufferClientCursorCopyWithImpl<$Res,
          RemoteFrameBufferClientCursor>;
  @useResult
  $Res call(
      {int height, int hotspotX, int hotspotY, ByteData pixels, int width});
}

/// @nodoc
class _$RemoteFrameBufferClientCursorCopyWithImpl<$Res,
        $Val extends RemoteFrameBufferClientCursor>
    implements $RemoteFrameBufferClientCursorCopyWith<$Res> {
  _$RemoteFrameBufferClientCursorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RemoteFrameBufferClientCursor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? height = null,
    Object? hotspotX = null,
    Object? hotspotY = null,
    Object? pixels = null,
    Object? width = null,
  }) {
    return _then(_value.copyWith(
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      hotspotX: null == hotspotX
          ? _value.hotspotX
          : hotspotX // ignore: cast_nullable_to_non_nullable
              as int,
      hotspotY: null == hotspotY
          ? _value.hotspotY
          : hotspotY // ignore: cast_nullable_to_non_nullable
              as int,
      pixels: null == pixels
          ? _value.pixels
          : pixels // ignore: cast_nullable_to_non_nullable
              as ByteData,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RemoteFrameBufferClientCursorImplCopyWith<$Res>
    implements $RemoteFrameBufferClientCursorCopyWith<$Res> {
  factory _$$RemoteFrameBufferClientCursorImplCopyWith(
          _$RemoteFrameBufferClientCursorImpl value,
          $Res Function(_$RemoteFrameBufferClientCursorImpl) then) =
      __$$RemoteFrameBufferClientCursorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int height, int hotspotX, int hotspotY, ByteData pixels, int width});
}

/// @nodoc
class __$$RemoteFrameBufferClientCursorImplCopyWithImpl<$Res>
    extends _$RemoteFrameBufferClientCursorCopyWithImpl<$Res,
        _$RemoteFrameBufferClientCursorImpl>
    implements _$$RemoteFrameBufferClientCursorImplCopyWith<$Res> {
  __$$RemoteFrameBufferClientCursorImplCopyWithImpl(
      _$RemoteFrameBufferClientCursorImpl _value,
      $Res Function(_$RemoteFrameBufferClientCursorImpl) _then)
      : super(_value, _then);

  /// Create a copy of RemoteFrameBufferClientCursor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? height = null,
    Object? hotspotX = null,
    Object? hotspotY = null,
    Object? pixels = null,
    Object? width = null,
  }) {
    return _then(_$RemoteFrameBufferClientCursorImpl(
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      hotspotX: null == hotspotX
          ? _value.hotspotX
          : hotspotX // ignore: cast_nullable_to_non_nullable
              as int,
      hotspotY: null == hotspotY
          ? _value.hotspotY
          : hotspotY // ignore: cast_nullable_to_non_nullable
              as int,
      pixels: null == pixels
          ? _value.pixels
          : pixels // ignore: cast_nullable_to_non_nullable
              as ByteData,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$RemoteFrameBufferClientCursorImpl
    extends _RemoteFrameBufferClientCursor {
  const _$RemoteFrameBufferClientCursorImpl(
      {required this.height,
      required this.hotspotX,
      required this.hotspotY,
      required this.pixels,
      required this.width})
      : super._();

  /// The height in pixels, 0 for an invisible cursor.
  @override
  final int height;

  /// The x offset of the hotspot, the point of the cursor at the pointer.
  @override
  final int hotspotX;

  /// The y offset of the hotspot.
  @override
  final int hotspotY;

  /// [width] x [height] BGRA8888 pixels. The alpha comes from the cursor
  /// bitmask: 255 where the cursor is drawn, 0 elsewhere, and the colour of
  /// transparent pixels is 0, so the pixels are both premultiplied and
  /// straight.
  @override
  final ByteData pixels;

  /// The width in pixels, 0 for an invisible cursor.
  @override
  final int width;

  @override
  String toString() {
    return 'RemoteFrameBufferClientCursor(height: $height, hotspotX: $hotspotX, hotspotY: $hotspotY, pixels: $pixels, width: $width)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemoteFrameBufferClientCursorImpl &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.hotspotX, hotspotX) ||
                other.hotspotX == hotspotX) &&
            (identical(other.hotspotY, hotspotY) ||
                other.hotspotY == hotspotY) &&
            (identical(other.pixels, pixels) || other.pixels == pixels) &&
            (identical(other.width, width) || other.width == width));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, height, hotspotX, hotspotY, pixels, width);

  /// Create a copy of RemoteFrameBufferClientCursor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemoteFrameBufferClientCursorImplCopyWith<
          _$RemoteFrameBufferClientCursorImpl>
      get copyWith => __$$RemoteFrameBufferClientCursorImplCopyWithImpl<
          _$RemoteFrameBufferClientCursorImpl>(this, _$identity);
}

abstract class _RemoteFrameBufferClientCursor
    extends RemoteFrameBufferClientCursor {
  const factory _RemoteFrameBufferClientCursor(
      {required final int height,
      required final int hotspotX,
      required final int hotspotY,
      required final ByteData pixels,
      required final int width}) = _$RemoteFrameBufferClientCursorImpl;
  const _RemoteFrameBufferClientCursor._() : super._();

  /// The height in pixels, 0 for an invisible cursor.
  @override
  int get height;

  /// The x offset of the hotspot, the point of the cursor at the pointer.
  @override
  int get hotspotX;

  /// The y offset of the hotspot.
  @override
  int get hotspotY;

  /// [width] x [height] BGRA8888 pixels. The alpha comes from the cursor
  /// bitmask: 255 where the cursor is drawn, 0 elsewhere, and the colour of
  /// transparent pixels is 0, so the pixels are both premultiplied and
  /// straight.
  @override
  ByteData get pixels;

  /// The width in pixels, 0 for an invisible cursor.
  @override
  int get width;

  /// Create a copy of RemoteFrameBufferClientCursor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemoteFrameBufferClientCursorImplCopyWith<
          _$RemoteFrameBufferClientCursorImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$RemoteFrameBufferClientUpdateRectangle {
  /// The [ByteData] that holds the pixel data of this rectangle.
  ByteData get byteData => throw _privateConstructorUsedError;

  /// The encoding used to interpret the bytes in [byteData].
  RemoteFrameBufferEncodingType get encodingType =>
      throw _privateConstructorUsedError;

  /// The height in pixels.
  int get height => throw _privateConstructorUsedError;

  /// The width in pixels.
  int get width => throw _privateConstructorUsedError;

  /// The starting x offset of this rectangle.
  int get x => throw _privateConstructorUsedError;

  /// The starting y offset of this rectangle.
  int get y => throw _privateConstructorUsedError;

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RemoteFrameBufferClientUpdateRectangleCopyWith<
          RemoteFrameBufferClientUpdateRectangle>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RemoteFrameBufferClientUpdateRectangleCopyWith<$Res> {
  factory $RemoteFrameBufferClientUpdateRectangleCopyWith(
          RemoteFrameBufferClientUpdateRectangle value,
          $Res Function(RemoteFrameBufferClientUpdateRectangle) then) =
      _$RemoteFrameBufferClientUpdateRectangleCopyWithImpl<$Res,
          RemoteFrameBufferClientUpdateRectangle>;
  @useResult
  $Res call(
      {ByteData byteData,
      RemoteFrameBufferEncodingType encodingType,
      int height,
      int width,
      int x,
      int y});

  $RemoteFrameBufferEncodingTypeCopyWith<$Res> get encodingType;
}

/// @nodoc
class _$RemoteFrameBufferClientUpdateRectangleCopyWithImpl<$Res,
        $Val extends RemoteFrameBufferClientUpdateRectangle>
    implements $RemoteFrameBufferClientUpdateRectangleCopyWith<$Res> {
  _$RemoteFrameBufferClientUpdateRectangleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? byteData = null,
    Object? encodingType = null,
    Object? height = null,
    Object? width = null,
    Object? x = null,
    Object? y = null,
  }) {
    return _then(_value.copyWith(
      byteData: null == byteData
          ? _value.byteData
          : byteData // ignore: cast_nullable_to_non_nullable
              as ByteData,
      encodingType: null == encodingType
          ? _value.encodingType
          : encodingType // ignore: cast_nullable_to_non_nullable
              as RemoteFrameBufferEncodingType,
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
      x: null == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as int,
      y: null == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RemoteFrameBufferEncodingTypeCopyWith<$Res> get encodingType {
    return $RemoteFrameBufferEncodingTypeCopyWith<$Res>(_value.encodingType,
        (value) {
      return _then(_value.copyWith(encodingType: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RemoteFrameBufferClientUpdateRectangleImplCopyWith<$Res>
    implements $RemoteFrameBufferClientUpdateRectangleCopyWith<$Res> {
  factory _$$RemoteFrameBufferClientUpdateRectangleImplCopyWith(
          _$RemoteFrameBufferClientUpdateRectangleImpl value,
          $Res Function(_$RemoteFrameBufferClientUpdateRectangleImpl) then) =
      __$$RemoteFrameBufferClientUpdateRectangleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ByteData byteData,
      RemoteFrameBufferEncodingType encodingType,
      int height,
      int width,
      int x,
      int y});

  @override
  $RemoteFrameBufferEncodingTypeCopyWith<$Res> get encodingType;
}

/// @nodoc
class __$$RemoteFrameBufferClientUpdateRectangleImplCopyWithImpl<$Res>
    extends _$RemoteFrameBufferClientUpdateRectangleCopyWithImpl<$Res,
        _$RemoteFrameBufferClientUpdateRectangleImpl>
    implements _$$RemoteFrameBufferClientUpdateRectangleImplCopyWith<$Res> {
  __$$RemoteFrameBufferClientUpdateRectangleImplCopyWithImpl(
      _$RemoteFrameBufferClientUpdateRectangleImpl _value,
      $Res Function(_$RemoteFrameBufferClientUpdateRectangleImpl) _then)
      : super(_value, _then);

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? byteData = null,
    Object? encodingType = null,
    Object? height = null,
    Object? width = null,
    Object? x = null,
    Object? y = null,
  }) {
    return _then(_$RemoteFrameBufferClientUpdateRectangleImpl(
      byteData: null == byteData
          ? _value.byteData
          : byteData // ignore: cast_nullable_to_non_nullable
              as ByteData,
      encodingType: null == encodingType
          ? _value.encodingType
          : encodingType // ignore: cast_nullable_to_non_nullable
              as RemoteFrameBufferEncodingType,
      height: null == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int,
      x: null == x
          ? _value.x
          : x // ignore: cast_nullable_to_non_nullable
              as int,
      y: null == y
          ? _value.y
          : y // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$RemoteFrameBufferClientUpdateRectangleImpl
    implements _RemoteFrameBufferClientUpdateRectangle {
  const _$RemoteFrameBufferClientUpdateRectangleImpl(
      {required this.byteData,
      required this.encodingType,
      required this.height,
      required this.width,
      required this.x,
      required this.y});

  /// The [ByteData] that holds the pixel data of this rectangle.
  @override
  final ByteData byteData;

  /// The encoding used to interpret the bytes in [byteData].
  @override
  final RemoteFrameBufferEncodingType encodingType;

  /// The height in pixels.
  @override
  final int height;

  /// The width in pixels.
  @override
  final int width;

  /// The starting x offset of this rectangle.
  @override
  final int x;

  /// The starting y offset of this rectangle.
  @override
  final int y;

  @override
  String toString() {
    return 'RemoteFrameBufferClientUpdateRectangle(byteData: $byteData, encodingType: $encodingType, height: $height, width: $width, x: $x, y: $y)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RemoteFrameBufferClientUpdateRectangleImpl &&
            (identical(other.byteData, byteData) ||
                other.byteData == byteData) &&
            (identical(other.encodingType, encodingType) ||
                other.encodingType == encodingType) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, byteData, encodingType, height, width, x, y);

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RemoteFrameBufferClientUpdateRectangleImplCopyWith<
          _$RemoteFrameBufferClientUpdateRectangleImpl>
      get copyWith =>
          __$$RemoteFrameBufferClientUpdateRectangleImplCopyWithImpl<
              _$RemoteFrameBufferClientUpdateRectangleImpl>(this, _$identity);
}

abstract class _RemoteFrameBufferClientUpdateRectangle
    implements RemoteFrameBufferClientUpdateRectangle {
  const factory _RemoteFrameBufferClientUpdateRectangle(
      {required final ByteData byteData,
      required final RemoteFrameBufferEncodingType encodingType,
      required final int height,
      required final int width,
      required final int x,
      required final int y}) = _$RemoteFrameBufferClientUpdateRectangleImpl;

  /// The [ByteData] that holds the pixel data of this rectangle.
  @override
  ByteData get byteData;

  /// The encoding used to interpret the bytes in [byteData].
  @override
  RemoteFrameBufferEncodingType get encodingType;

  /// The height in pixels.
  @override
  int get height;

  /// The width in pixels.
  @override
  int get width;

  /// The starting x offset of this rectangle.
  @override
  int get x;

  /// The starting y offset of this rectangle.
  @override
  int get y;

  /// Create a copy of RemoteFrameBufferClientUpdateRectangle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RemoteFrameBufferClientUpdateRectangleImplCopyWith<
          _$RemoteFrameBufferClientUpdateRectangleImpl>
      get copyWith => throw _privateConstructorUsedError;
}
