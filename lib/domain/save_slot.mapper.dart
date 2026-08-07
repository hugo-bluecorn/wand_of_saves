// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'save_slot.dart';

class SaveSlotMapper extends ClassMapperBase<SaveSlot> {
  SaveSlotMapper._();

  static SaveSlotMapper? _instance;
  static SaveSlotMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SaveSlotMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SaveSlot';

  static String _$directoryName(SaveSlot v) => v.directoryName;
  static const Field<SaveSlot, String> _f$directoryName = Field(
    'directoryName',
    _$directoryName,
  );
  static String _$path(SaveSlot v) => v.path;
  static const Field<SaveSlot, String> _f$path = Field('path', _$path);
  static String _$area(SaveSlot v) => v.area;
  static const Field<SaveSlot, String> _f$area = Field('area', _$area);
  static int _$gameTime(SaveSlot v) => v.gameTime;
  static const Field<SaveSlot, int> _f$gameTime = Field('gameTime', _$gameTime);
  static int _$partySize(SaveSlot v) => v.partySize;
  static const Field<SaveSlot, int> _f$partySize = Field(
    'partySize',
    _$partySize,
  );
  static int _$gold(SaveSlot v) => v.gold;
  static const Field<SaveSlot, int> _f$gold = Field('gold', _$gold);
  static DateTime _$modified(SaveSlot v) => v.modified;
  static const Field<SaveSlot, DateTime> _f$modified = Field(
    'modified',
    _$modified,
  );
  static String? _$screenshotPath(SaveSlot v) => v.screenshotPath;
  static const Field<SaveSlot, String> _f$screenshotPath = Field(
    'screenshotPath',
    _$screenshotPath,
    opt: true,
  );

  @override
  final MappableFields<SaveSlot> fields = const {
    #directoryName: _f$directoryName,
    #path: _f$path,
    #area: _f$area,
    #gameTime: _f$gameTime,
    #partySize: _f$partySize,
    #gold: _f$gold,
    #modified: _f$modified,
    #screenshotPath: _f$screenshotPath,
  };

  static SaveSlot _instantiate(DecodingData data) {
    return SaveSlot(
      directoryName: data.dec(_f$directoryName),
      path: data.dec(_f$path),
      area: data.dec(_f$area),
      gameTime: data.dec(_f$gameTime),
      partySize: data.dec(_f$partySize),
      gold: data.dec(_f$gold),
      modified: data.dec(_f$modified),
      screenshotPath: data.dec(_f$screenshotPath),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SaveSlot fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SaveSlot>(map);
  }

  static SaveSlot fromJson(String json) {
    return ensureInitialized().decodeJson<SaveSlot>(json);
  }
}

mixin SaveSlotMappable {
  String toJson() {
    return SaveSlotMapper.ensureInitialized().encodeJson<SaveSlot>(
      this as SaveSlot,
    );
  }

  Map<String, dynamic> toMap() {
    return SaveSlotMapper.ensureInitialized().encodeMap<SaveSlot>(
      this as SaveSlot,
    );
  }

  SaveSlotCopyWith<SaveSlot, SaveSlot, SaveSlot> get copyWith =>
      _SaveSlotCopyWithImpl<SaveSlot, SaveSlot>(
        this as SaveSlot,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SaveSlotMapper.ensureInitialized().stringifyValue(this as SaveSlot);
  }

  @override
  bool operator ==(Object other) {
    return SaveSlotMapper.ensureInitialized().equalsValue(
      this as SaveSlot,
      other,
    );
  }

  @override
  int get hashCode {
    return SaveSlotMapper.ensureInitialized().hashValue(this as SaveSlot);
  }
}

extension SaveSlotValueCopy<$R, $Out> on ObjectCopyWith<$R, SaveSlot, $Out> {
  SaveSlotCopyWith<$R, SaveSlot, $Out> get $asSaveSlot =>
      $base.as((v, t, t2) => _SaveSlotCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SaveSlotCopyWith<$R, $In extends SaveSlot, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? directoryName,
    String? path,
    String? area,
    int? gameTime,
    int? partySize,
    int? gold,
    DateTime? modified,
    String? screenshotPath,
  });
  SaveSlotCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SaveSlotCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SaveSlot, $Out>
    implements SaveSlotCopyWith<$R, SaveSlot, $Out> {
  _SaveSlotCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SaveSlot> $mapper =
      SaveSlotMapper.ensureInitialized();
  @override
  $R call({
    String? directoryName,
    String? path,
    String? area,
    int? gameTime,
    int? partySize,
    int? gold,
    DateTime? modified,
    Object? screenshotPath = $none,
  }) => $apply(
    FieldCopyWithData({
      if (directoryName != null) #directoryName: directoryName,
      if (path != null) #path: path,
      if (area != null) #area: area,
      if (gameTime != null) #gameTime: gameTime,
      if (partySize != null) #partySize: partySize,
      if (gold != null) #gold: gold,
      if (modified != null) #modified: modified,
      if (screenshotPath != $none) #screenshotPath: screenshotPath,
    }),
  );
  @override
  SaveSlot $make(CopyWithData data) => SaveSlot(
    directoryName: data.get(#directoryName, or: $value.directoryName),
    path: data.get(#path, or: $value.path),
    area: data.get(#area, or: $value.area),
    gameTime: data.get(#gameTime, or: $value.gameTime),
    partySize: data.get(#partySize, or: $value.partySize),
    gold: data.get(#gold, or: $value.gold),
    modified: data.get(#modified, or: $value.modified),
    screenshotPath: data.get(#screenshotPath, or: $value.screenshotPath),
  );

  @override
  SaveSlotCopyWith<$R2, SaveSlot, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SaveSlotCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

