// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vault.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EncryptionResult {

 Uint8List get nonce;
/// Create a copy of EncryptionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EncryptionResultCopyWith<EncryptionResult> get copyWith => _$EncryptionResultCopyWithImpl<EncryptionResult>(this as EncryptionResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EncryptionResult&&const DeepCollectionEquality().equals(other.nonce, nonce));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(nonce));

@override
String toString() {
  return 'EncryptionResult(nonce: $nonce)';
}


}

/// @nodoc
abstract mixin class $EncryptionResultCopyWith<$Res>  {
  factory $EncryptionResultCopyWith(EncryptionResult value, $Res Function(EncryptionResult) _then) = _$EncryptionResultCopyWithImpl;
@useResult
$Res call({
 Uint8List nonce
});




}
/// @nodoc
class _$EncryptionResultCopyWithImpl<$Res>
    implements $EncryptionResultCopyWith<$Res> {
  _$EncryptionResultCopyWithImpl(this._self, this._then);

  final EncryptionResult _self;
  final $Res Function(EncryptionResult) _then;

/// Create a copy of EncryptionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nonce = null,}) {
  return _then(_self.copyWith(
nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}

}


/// Adds pattern-matching-related methods to [EncryptionResult].
extension EncryptionResultPatterns on EncryptionResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EncryptionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EncryptionResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EncryptionResult value)  $default,){
final _that = this;
switch (_that) {
case _EncryptionResult():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EncryptionResult value)?  $default,){
final _that = this;
switch (_that) {
case _EncryptionResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List nonce)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EncryptionResult() when $default != null:
return $default(_that.nonce);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List nonce)  $default,) {final _that = this;
switch (_that) {
case _EncryptionResult():
return $default(_that.nonce);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List nonce)?  $default,) {final _that = this;
switch (_that) {
case _EncryptionResult() when $default != null:
return $default(_that.nonce);case _:
  return null;

}
}

}

/// @nodoc


class _EncryptionResult implements EncryptionResult {
  const _EncryptionResult({required this.nonce});
  

@override final  Uint8List nonce;

/// Create a copy of EncryptionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EncryptionResultCopyWith<_EncryptionResult> get copyWith => __$EncryptionResultCopyWithImpl<_EncryptionResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EncryptionResult&&const DeepCollectionEquality().equals(other.nonce, nonce));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(nonce));

@override
String toString() {
  return 'EncryptionResult(nonce: $nonce)';
}


}

/// @nodoc
abstract mixin class _$EncryptionResultCopyWith<$Res> implements $EncryptionResultCopyWith<$Res> {
  factory _$EncryptionResultCopyWith(_EncryptionResult value, $Res Function(_EncryptionResult) _then) = __$EncryptionResultCopyWithImpl;
@override @useResult
$Res call({
 Uint8List nonce
});




}
/// @nodoc
class __$EncryptionResultCopyWithImpl<$Res>
    implements _$EncryptionResultCopyWith<$Res> {
  __$EncryptionResultCopyWithImpl(this._self, this._then);

  final _EncryptionResult _self;
  final $Res Function(_EncryptionResult) _then;

/// Create a copy of EncryptionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nonce = null,}) {
  return _then(_EncryptionResult(
nonce: null == nonce ? _self.nonce : nonce // ignore: cast_nullable_to_non_nullable
as Uint8List,
  ));
}


}

// dart format on
