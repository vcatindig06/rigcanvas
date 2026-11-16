import 'dart:convert';

const int currentAssetSchemaVersion = 1;
const int maximumLibraryAssets = 500;
const int maximumAssetFileBytes = 64 * 1024 * 1024;

enum RigAssetKind { ampCapture, cabinetIr }

enum RigAssetValidation { validated, unverified }

class RigAsset {
  const RigAsset({
    required this.id,
    required this.title,
    required this.kind,
    required this.originalFilename,
    required this.storedFilename,
    required this.extension,
    required this.fileSizeBytes,
    required this.importedAt,
    required this.validation,
    required this.formatSummary,
    this.manufacturer = '',
    this.model = '',
    this.tags = const <String>[],
    this.notes = '',
    this.isFavorite = false,
    this.sampleRateHz,
    this.channelCount,
    this.bitDepth,
  });

  final String id;
  final String title;
  final RigAssetKind kind;
  final String originalFilename;
  final String storedFilename;
  final String extension;
  final int fileSizeBytes;
  final DateTime importedAt;
  final RigAssetValidation validation;
  final String formatSummary;
  final String manufacturer;
  final String model;
  final List<String> tags;
  final String notes;
  final bool isFavorite;
  final int? sampleRateHz;
  final int? channelCount;
  final int? bitDepth;

  RigAsset copyWith({
    String? title,
    String? manufacturer,
    String? model,
    List<String>? tags,
    String? notes,
    bool? isFavorite,
  }) {
    return RigAsset(
      id: id,
      title: title ?? this.title,
      kind: kind,
      originalFilename: originalFilename,
      storedFilename: storedFilename,
      extension: extension,
      fileSizeBytes: fileSizeBytes,
      importedAt: importedAt,
      validation: validation,
      formatSummary: formatSummary,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      sampleRateHz: sampleRateHz,
      channelCount: channelCount,
      bitDepth: bitDepth,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'originalFilename': originalFilename,
    'storedFilename': storedFilename,
    'extension': extension,
    'fileSizeBytes': fileSizeBytes,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'validation': validation.name,
    'formatSummary': formatSummary,
    'manufacturer': manufacturer,
    'model': model,
    'tags': tags,
    'notes': notes,
    'isFavorite': isFavorite,
    'sampleRateHz': sampleRateHz,
    'channelCount': channelCount,
    'bitDepth': bitDepth,
  };

  factory RigAsset.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Asset entry must be a JSON object.');
    }

    final id = _readString(value, 'id', maximumLength: 128);
    final title = _readString(value, 'title', maximumLength: 100);
    final kindName = _readString(value, 'kind', maximumLength: 32);
    final kind = RigAssetKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => throw FormatException('Unsupported asset kind "$kindName".'),
    );
    final originalFilename = _readString(
      value,
      'originalFilename',
      maximumLength: 255,
    );
    final storedFilename = _readString(
      value,
      'storedFilename',
      maximumLength: 180,
    );
    if (!RegExp(r'^[a-zA-Z0-9_-]+[.][a-z0-9]{1,8}$').hasMatch(storedFilename)) {
      throw const FormatException('Asset storage filename is invalid.');
    }
    final extension = _readString(value, 'extension', maximumLength: 8);
    if (extension != extension.toLowerCase() ||
        !RegExp(r'^[.][a-z0-9]{1,8}$').hasMatch(extension) ||
        !storedFilename.toLowerCase().endsWith(extension)) {
      throw const FormatException('Asset extension is invalid.');
    }
    final fileSizeBytes = value['fileSizeBytes'];
    if (fileSizeBytes is! int ||
        fileSizeBytes < 1 ||
        fileSizeBytes > maximumAssetFileBytes) {
      throw const FormatException('Asset file size is invalid.');
    }
    final importedAt = _readDate(value, 'importedAt');
    final validationName = _readString(
      value,
      'validation',
      maximumLength: 24,
    );
    final validation = RigAssetValidation.values.firstWhere(
      (candidate) => candidate.name == validationName,
      orElse: () => throw const FormatException('Asset validation state is invalid.'),
    );
    final formatSummary = _readString(
      value,
      'formatSummary',
      maximumLength: 400,
      allowEmpty: true,
    );
    final manufacturer = _readString(
      value,
      'manufacturer',
      maximumLength: 80,
      allowEmpty: true,
    );
    final model = _readString(
      value,
      'model',
      maximumLength: 100,
      allowEmpty: true,
    );
    final notes = _readString(
      value,
      'notes',
      maximumLength: 500,
      allowEmpty: true,
    );
    final rawTags = value['tags'];
    if (rawTags is! List || rawTags.length > 20) {
      throw const FormatException('Asset tags must be a list of up to 20 items.');
    }
    final tags = rawTags.map((tag) {
      if (tag is! String || tag.trim().isEmpty || tag.trim().length > 24) {
        throw const FormatException('Asset tag is invalid.');
      }
      return tag.trim();
    }).toList();
    if (tags.toSet().length != tags.length) {
      throw const FormatException('Asset contains duplicate tags.');
    }
    final favorite = value['isFavorite'];
    if (favorite is! bool) {
      throw const FormatException('Asset favorite flag must be boolean.');
    }

    return RigAsset(
      id: id,
      title: title.trim(),
      kind: kind,
      originalFilename: originalFilename,
      storedFilename: storedFilename,
      extension: extension,
      fileSizeBytes: fileSizeBytes,
      importedAt: importedAt,
      validation: validation,
      formatSummary: formatSummary,
      manufacturer: manufacturer,
      model: model,
      tags: tags,
      notes: notes,
      isFavorite: favorite,
      sampleRateHz: _readOptionalPositiveInt(value['sampleRateHz'], 'sampleRateHz'),
      channelCount: _readOptionalPositiveInt(value['channelCount'], 'channelCount'),
      bitDepth: _readOptionalPositiveInt(value['bitDepth'], 'bitDepth'),
    );
  }
}

class AssetDocumentCodec {
  const AssetDocumentCodec._();

  static String encode(List<RigAsset> assets) {
    if (assets.length > maximumLibraryAssets) {
      throw const FormatException('The asset library limit has been reached.');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': currentAssetSchemaVersion,
      'assets': assets.map((asset) => asset.toJson()).toList(),
    });
  }

  static List<RigAsset> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Asset database must be a JSON object.');
    }
    if (decoded['schemaVersion'] != currentAssetSchemaVersion) {
      throw FormatException(
        'Unsupported asset database schema: ${decoded['schemaVersion']}.',
      );
    }
    final rawAssets = decoded['assets'];
    if (rawAssets is! List || rawAssets.length > maximumLibraryAssets) {
      throw const FormatException('Asset database contains an invalid asset list.');
    }
    final assets = rawAssets.map(RigAsset.fromJson).toList();
    final ids = assets.map((asset) => asset.id).toSet();
    final filenames = assets.map((asset) => asset.storedFilename).toSet();
    if (ids.length != assets.length || filenames.length != assets.length) {
      throw const FormatException('Asset database contains duplicate IDs or files.');
    }
    return assets;
  }
}

String _readString(
  Map<String, dynamic> source,
  String key, {
  required int maximumLength,
  bool allowEmpty = false,
}) {
  final value = source[key];
  if (value is! String ||
      value.length > maximumLength ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Invalid or missing "$key" field.');
  }
  return value;
}

DateTime _readDate(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! String) {
    throw FormatException('Invalid or missing "$key" date.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid "$key" date.');
  }
  return parsed.toUtc();
}

int? _readOptionalPositiveInt(Object? value, String field) {
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException('Invalid "$field" value.');
  }
  return value;
}
