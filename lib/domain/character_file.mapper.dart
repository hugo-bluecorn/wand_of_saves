// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'character_file.dart';

class CharacterFileMapper extends ClassMapperBase<CharacterFile> {
  CharacterFileMapper._();

  static CharacterFileMapper? _instance;
  static CharacterFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CharacterFileMapper._());
      CharacterMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CharacterFile';

  static String _$fileName(CharacterFile v) => v.fileName;
  static const Field<CharacterFile, String> _f$fileName = Field(
    'fileName',
    _$fileName,
  );
  static String _$path(CharacterFile v) => v.path;
  static const Field<CharacterFile, String> _f$path = Field('path', _$path);
  static Character _$character(CharacterFile v) => v.character;
  static const Field<CharacterFile, Character> _f$character = Field(
    'character',
    _$character,
  );
  static DateTime _$modified(CharacterFile v) => v.modified;
  static const Field<CharacterFile, DateTime> _f$modified = Field(
    'modified',
    _$modified,
  );

  @override
  final MappableFields<CharacterFile> fields = const {
    #fileName: _f$fileName,
    #path: _f$path,
    #character: _f$character,
    #modified: _f$modified,
  };

  static CharacterFile _instantiate(DecodingData data) {
    return CharacterFile(
      fileName: data.dec(_f$fileName),
      path: data.dec(_f$path),
      character: data.dec(_f$character),
      modified: data.dec(_f$modified),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CharacterFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CharacterFile>(map);
  }

  static CharacterFile fromJson(String json) {
    return ensureInitialized().decodeJson<CharacterFile>(json);
  }
}

mixin CharacterFileMappable {
  String toJson() {
    return CharacterFileMapper.ensureInitialized().encodeJson<CharacterFile>(
      this as CharacterFile,
    );
  }

  Map<String, dynamic> toMap() {
    return CharacterFileMapper.ensureInitialized().encodeMap<CharacterFile>(
      this as CharacterFile,
    );
  }

  CharacterFileCopyWith<CharacterFile, CharacterFile, CharacterFile>
  get copyWith => _CharacterFileCopyWithImpl<CharacterFile, CharacterFile>(
    this as CharacterFile,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CharacterFileMapper.ensureInitialized().stringifyValue(
      this as CharacterFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return CharacterFileMapper.ensureInitialized().equalsValue(
      this as CharacterFile,
      other,
    );
  }

  @override
  int get hashCode {
    return CharacterFileMapper.ensureInitialized().hashValue(
      this as CharacterFile,
    );
  }
}

extension CharacterFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CharacterFile, $Out> {
  CharacterFileCopyWith<$R, CharacterFile, $Out> get $asCharacterFile =>
      $base.as((v, t, t2) => _CharacterFileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CharacterFileCopyWith<$R, $In extends CharacterFile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  CharacterCopyWith<$R, Character, Character> get character;
  $R call({
    String? fileName,
    String? path,
    Character? character,
    DateTime? modified,
  });
  CharacterFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CharacterFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CharacterFile, $Out>
    implements CharacterFileCopyWith<$R, CharacterFile, $Out> {
  _CharacterFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CharacterFile> $mapper =
      CharacterFileMapper.ensureInitialized();
  @override
  CharacterCopyWith<$R, Character, Character> get character =>
      $value.character.copyWith.$chain((v) => call(character: v));
  @override
  $R call({
    String? fileName,
    String? path,
    Character? character,
    DateTime? modified,
  }) => $apply(
    FieldCopyWithData({
      if (fileName != null) #fileName: fileName,
      if (path != null) #path: path,
      if (character != null) #character: character,
      if (modified != null) #modified: modified,
    }),
  );
  @override
  CharacterFile $make(CopyWithData data) => CharacterFile(
    fileName: data.get(#fileName, or: $value.fileName),
    path: data.get(#path, or: $value.path),
    character: data.get(#character, or: $value.character),
    modified: data.get(#modified, or: $value.modified),
  );

  @override
  CharacterFileCopyWith<$R2, CharacterFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CharacterFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

